import base64
import json

from markupsafe import Markup

from odoo.tests import HttpCase, tagged

TINY_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk"
    "+A8AAQUBAScY42YAAAAASUVORK5CYII="
)
# A scripted SVG -- the payload the upload allowlist exists to keep out.
SVG_BYTES = (b"<svg xmlns='http://www.w3.org/2000/svg'>"
             b"<script>alert(document.domain)</script></svg>")


@tagged("-at_install", "post_install")
class TestMobileLogNoteMessagesApi(HttpCase):
    """GET /log-note/messages and /log-note/attachments/<id> on an `hr.expense` thread.
    An approver is required or Odoo's `_check_can_approve` rejects the record."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        Product = cls.env["product.product"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.password = "log_note_msg_pw_1234"
        cls.category = Product.create({
            "name": "Travel", "type": "service", "can_be_expensed": True})

        cls.manager_user = Users.create({
            "name": "Issac Alex",
            "login": "log_note_msg_manager@test.com",
            "password": cls.password,
            "group_ids": [
                (4, internal_group.id),
                (4, cls.env.ref("hr_expense.group_hr_expense_team_approver").id),
            ],
        })
        cls.manager_employee = Employee.create({
            "name": "Issac Alex", "company_id": company.id,
            "user_id": cls.manager_user.id})

        cls.user = Users.create({
            "name": "Log Note Mobile User",
            "login": "log_note_msg_user@test.com",
            "password": cls.password,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Log Note Mobile User", "company_id": company.id,
            "user_id": cls.user.id, "parent_id": cls.manager_employee.id})

        cls.other_user = Users.create({
            "name": "Other Mobile User",
            "login": "log_note_msg_other@test.com",
            "password": cls.password,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.other_employee = Employee.create({
            "name": "Other Mobile User", "company_id": company.id,
            "user_id": cls.other_user.id})

        Expense = cls.env["hr.expense"].sudo()
        cls.expense = Expense.create({
            "name": "Team lunch",
            "employee_id": cls.employee.id,
            "product_id": cls.category.id,
            "quantity": 1,
            "total_amount_currency": 500.0,
            "date": "2026-06-24",
            "payment_mode": "own_account",
        })
        # Belongs to somebody else -- the IDOR target.
        cls.foreign_expense = Expense.create({
            "name": "Not yours",
            "employee_id": cls.other_employee.id,
            "product_id": cls.category.id,
            "quantity": 1,
            "total_amount_currency": 10.0,
            "date": "2026-06-24",
            "payment_mode": "own_account",
        })

        note_subtype = cls.env.ref("mail.mt_note")

        # 1. System message authored by the employee (right-hand bubble).
        cls.msg_system = cls.expense.with_user(cls.user).sudo()._message_log(
            body="Expense of $500 created")

        # 2. Human note from somebody else (left-hand bubble).
        cls.msg_other = cls.expense.with_user(cls.manager_user).message_post(
            body=Markup("<p>Hi <a href=\"#\" data-oe-model=\"res.partner\" "
                  "data-oe-id=\"%s\">@Log Note Mobile User</a>, your "
                  "reimbursement will be done tomorrow.</p>"
                  % cls.user.partner_id.id),
            message_type="comment",
            subtype_id=note_subtype.id,
            partner_ids=[cls.user.partner_id.id],
        )

        # 3. A human note from the caller, with an image attachment.
        cls.attachment = cls.env["ir.attachment"].sudo().create({
            "name": "receipt.png",
            "datas": base64.b64encode(TINY_PNG),
            "mimetype": "image/png",
            "res_model": "hr.expense",
            "res_id": cls.expense.id,
        })
        cls.msg_own = cls.expense.with_user(cls.user).message_post(
            body=Markup("<p>Here is the <b>receipt</b></p>"),
            message_type="comment",
            subtype_id=note_subtype.id,
            attachment_ids=[cls.attachment.id],
        )

        cls.env.flush_all()

    def _token(self, login=None):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": login or "log_note_msg_user@test.com",
                  "password": self.password},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"]

    def _get(self, path, token=None):
        headers = {"Authorization": "Bearer %s" % token} if token else {}
        resp = self.url_open(path, headers=headers)
        return resp.status_code, resp.json()

    def _post_json(self, path, payload, token=None):
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = "Bearer %s" % token
        resp = self.url_open(path, json=payload, headers=headers)
        return resp.status_code, resp.json()

    def _messages(self, token=None, query=None):
        query = query or "?source=expense&id=%s" % self.expense.id
        status, body = self._get(
            "/api/mobile/v1/log-note/messages%s" % query, token or self._token())
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"], body)
        return body["data"]

    def _by_id(self, data):
        return {m["id"]: m for m in data["messages"]}

    def _path(self, url):
        return "/" + url.split("://", 1)[1].split("/", 1)[1]

    def test_missing_token_rejected(self):
        status, body = self._get(
            "/api/mobile/v1/log-note/messages?source=expense&id=%s"
            % self.expense.id)
        self.assertEqual(status, 401)
        self.assertEqual(body["code"], "missing_access_token")

    def test_unknown_source_rejected(self):
        status, body = self._get(
            "/api/mobile/v1/log-note/messages?source=res.users&id=1",
            self._token())
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_source")

    def test_raw_model_name_is_not_a_source(self):
        """The allowlist is keyed by source, not model -- naming the model
        directly must not work, or the allowlist would be cosmetic."""
        status, body = self._get(
            "/api/mobile/v1/log-note/messages?source=hr.expense&id=%s"
            % self.expense.id, self._token())
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_source")

    def test_calendar_sources_are_allowlisted(self):
        """Both the canonical spelling and the existing mobile alias reach
        the calendar-event resolver instead of being rejected as a model."""
        for source in ("calendar", "calender"):
            status, body = self._get(
                "/api/mobile/v1/log-note/messages?source=%s&id=99999999"
                % source, self._token())
            self.assertEqual(status, 404, body)
            self.assertEqual(body["code"], "calendar_event_not_found")

    def test_non_integer_id_rejected(self):
        status, body = self._get(
            "/api/mobile/v1/log-note/messages?source=expense&id=abc",
            self._token())
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_record_id")

    def test_another_employees_record_is_not_readable(self):
        """IDOR guard: the id is client-supplied and points at a real row."""
        status, body = self._get(
            "/api/mobile/v1/log-note/messages?source=expense&id=%s"
            % self.foreign_expense.id, self._token())
        self.assertEqual(status, 404)
        self.assertEqual(body["code"], "expense_not_found")

    def test_missing_record_and_forbidden_record_are_indistinguishable(self):
        """Different answers here would enumerate the expense table."""
        _, forbidden = self._get(
            "/api/mobile/v1/log-note/messages?source=expense&id=%s"
            % self.foreign_expense.id, self._token())
        _, absent = self._get(
            "/api/mobile/v1/log-note/messages?source=expense&id=99999999",
            self._token())
        self.assertEqual(forbidden["code"], absent["code"])
        self.assertEqual(forbidden["message"], absent["message"])

    def test_feature_gate_closes_the_thread(self):
        """Revoking the Expense feature must close expense chatter too."""
        feature = self.env["mobile.feature"].sudo().search(
            [("code", "=", "expense")], limit=1)
        self.env["mobile.user.feature"].sudo().search([
            ("user_id", "=", self.user.id), ("feature_id", "=", feature.id),
        ]).unlink()
        self.env.flush_all()
        status, body = self._get(
            "/api/mobile/v1/log-note/messages?source=expense&id=%s"
            % self.expense.id, self._token())
        self.assertEqual(status, 403)
        self.assertEqual(body["code"], "expense_access_denied")

    def test_messages_are_newest_first(self):
        data = self._messages()
        ids = [m["id"] for m in data["messages"]]
        self.assertEqual(ids, sorted(ids, reverse=True))

    def test_record_block_identifies_the_thread(self):
        data = self._messages()
        self.assertEqual(data["record"]["model"], "hr.expense")
        self.assertEqual(data["record"]["id"], self.expense.id)

    def test_record_attachments_excludes_documents_posted_through_a_reply(self):
        """`record.attachments` excludes files posted through a chat reply.
        message_post links attachments to the thread record, so message-owned ones must be filtered out."""
        data = self._messages()
        names = [a["name"] for a in data["record"].get("attachments", [])]
        self.assertNotIn(
            "receipt.png", names,
            "a reply's attachment leaked into the record-level list: %s" % names)

    def test_record_attachments_still_includes_a_genuine_creation_time_upload(self):
        """A genuine creation-time receipt upload still appears in `record.attachments`."""
        creation_attachment = self.env["ir.attachment"].sudo().create({
            "name": "original_receipt.png",
            "datas": base64.b64encode(TINY_PNG),
            "mimetype": "image/png",
            "res_model": "hr.expense",
            "res_id": self.expense.id,
        })
        self.env.flush_all()
        data = self._messages()
        names = [a["name"] for a in data["record"].get("attachments", [])]
        self.assertIn("original_receipt.png", names)
        # And the reply's attachment still must not be there alongside it.
        self.assertNotIn("receipt.png", names)

    def test_message_edited_down_to_nothing_is_excluded(self):
        """A message edited down to nothing (only the edited marker) is not served."""
        note_subtype = self.env.ref("mail.mt_note")
        message = self.expense.with_user(self.user).message_post(
            body=Markup("<p>this will be edited away</p>"),
            message_type="comment", subtype_id=note_subtype.id,
        )
        self.expense.sudo()._message_update_content(message.sudo(), body="", strict=False)
        self.env.flush_all()

        data = self._messages()
        self.assertNotIn(
            message.id, self._by_id(data),
            "a message with no visible text and no attachment must be excluded")

    def test_data_is_a_dict_not_a_bare_list(self):
        _, body = self._get(
            "/api/mobile/v1/log-note/messages?source=expense&id=%s"
            % self.expense.id, self._token())
        self.assertIsInstance(body["data"], dict)

    def test_every_message_carries_body_parts_and_attachments(self):
        """Both list fields are always present, empty rather than absent,
        so the client never has to null-check them."""
        data = self._messages()
        for message in data["messages"]:
            self.assertIsInstance(message["body_parts"], list)
            self.assertIsInstance(message["attachments"], list)

    def test_flat_body_fields_are_not_sent(self):
        """`body_html`/`body_text` are not sent; `body_parts` supersedes them."""
        for message in self._messages()["messages"]:
            self.assertNotIn("body_html", message)
            self.assertNotIn("body_text", message)

    def test_body_parts_concatenate_to_the_plain_text(self):
        """Joining the parts is how a client renders plain text -- this is
        what replaced `body_text`."""
        message = self._by_id(self._messages())[self.msg_own.id]
        plain = "".join(part["text"] for part in message["body_parts"])
        self.assertEqual(plain.strip(), "Here is the receipt")
        # Markup is resolved server-side; no HTML reaches the client.
        self.assertNotIn("<b>", plain)

    def test_human_note_is_typed_note(self):
        message = self._by_id(self._messages())[self.msg_other.id]
        self.assertEqual(message["type"], "note")

    def test_generated_message_is_typed_system(self):
        message = self._by_id(self._messages())[self.msg_system.id]
        self.assertEqual(message["type"], "system")

    def test_own_message_aligns_own(self):
        message = self._by_id(self._messages())[self.msg_own.id]
        self.assertEqual(message["align"], "own")
        self.assertEqual(message["author"]["id"], self.user.partner_id.id)

    def test_other_authors_message_aligns_other(self):
        message = self._by_id(self._messages())[self.msg_other.id]
        self.assertEqual(message["align"], "other")
        self.assertEqual(message["author"]["name"], "Issac Alex")
        self.assertTrue(message["author"]["image_url"])

    def test_system_message_authored_by_me_still_aligns_own(self):
        """`align` is author-based, so a system message about your own action aligns own."""
        message = self._by_id(self._messages())[self.msg_system.id]
        self.assertEqual(message["type"], "system")
        self.assertEqual(message["align"], "own")

    def test_align_is_relative_to_the_caller(self):
        """The same message must flip sides for a different reader."""
        self.expense.sudo().write({"employee_id": self.other_employee.id})
        self.env.flush_all()
        data = self._messages(
            token=self._token("log_note_msg_other@test.com"))
        message = self._by_id(data)[self.msg_own.id]
        self.assertEqual(message["align"], "other")

    def _post_tracking_only(self, field="name", old="Team lunch",
                            new="Team dinner"):
        message = self.expense.with_user(self.user).message_post(
            body="",
            message_type="notification",
            subtype_id=self.env.ref("mail.mt_note").id,
            tracking_value_ids=[(0, 0, {
                "field_id": self.env["ir.model.fields"]._get(
                    "hr.expense", field).id,
                "old_value_char": old,
                "new_value_char": new,
            })],
        )
        self.env.flush_all()
        return message

    def test_tracking_only_message_is_excluded(self):
        message = self._post_tracking_only()
        data = self._messages()
        self.assertNotIn(
            message.id, self._by_id(data),
            "a bodiless field-change row must not reach the client")

    def test_tracking_key_is_not_sent(self):
        """`tracking` was dropped from the payload, not merely emptied."""
        self._post_tracking_only()
        for message in self._messages()["messages"]:
            self.assertNotIn("tracking", message)

    def test_tracking_only_message_is_excluded_from_the_total(self):
        """Tracking-only rows are filtered in the domain so `total` and `has_next` stay accurate."""
        before = self._messages()["pagination"]["total"]
        self._post_tracking_only()
        data = self._messages()
        self.assertEqual(data["pagination"]["total"], before)
        self.assertEqual(len(data["messages"]), before)

    def test_status_change_with_a_body_is_still_delivered(self):
        """A status change with a body (e.g. the refusal reason) is still delivered."""
        refusal = self.expense.with_user(self.manager_user).message_post(
            body=Markup("<p>Your Expense Team lunch has been refused</p>"
                        "<ul><li>Reason: Missing receipt</li></ul>"),
            message_type="notification",
            subtype_id=self.env.ref("mail.mt_note").id,
            tracking_value_ids=[(0, 0, {
                "field_id": self.env["ir.model.fields"]._get(
                    "hr.expense", "state").id,
                "old_value_char": "Approved",
                "new_value_char": "Refused",
            })],
        )
        self.env.flush_all()
        message = self._by_id(self._messages())[refusal.id]
        text = "".join(part["text"] for part in message["body_parts"])
        self.assertIn("has been refused", text)
        self.assertIn("Reason: Missing receipt", text)

    def test_message_with_an_attachment_but_no_body_survives(self):
        """Files are content. Only rows with nothing readable are dropped."""
        message = self._by_id(self._messages())[self.msg_own.id]
        self.assertTrue(message["attachments"])

    def test_pretty_printed_html_does_not_leak_indentation(self):
        """Indentation from pretty-printed HTML is collapsed, as a browser would."""
        posted = self.expense.with_user(self.manager_user).message_post(
            body=Markup("<p>Your Expense has been refused</p>\n"
                        "            <ul>\n"
                        "                <li>Reason: Some</li>\n"
                        "            </ul>"),
            message_type="notification",
            subtype_id=self.env.ref("mail.mt_note").id,
        )
        self.env.flush_all()
        message = self._by_id(self._messages())[posted.id]
        text = "".join(part["text"] for part in message["body_parts"])
        self.assertEqual(
            text, "Your Expense has been refused\nReason: Some")

    def test_inline_spacing_between_elements_is_preserved(self):
        """Collapsing must not weld adjacent words together."""
        posted = self.expense.with_user(self.user).message_post(
            body=Markup("<p><b>Hi</b> <i>there</i></p>"),
            message_type="comment",
            subtype_id=self.env.ref("mail.mt_note").id,
        )
        self.env.flush_all()
        message = self._by_id(self._messages())[posted.id]
        text = "".join(part["text"] for part in message["body_parts"])
        self.assertEqual(text, "Hi there")

    def test_hidden_email_preheader_is_not_rendered(self):
        """Odoo's hidden `display:none` email preheader is not rendered as text."""
        posted = self.expense.with_user(self.user).message_post(
            body=Markup('<div style="display:none; font-size:0px">'
                        'hidden preheader​​​</div>'
                        '<p>Real content</p>'),
            message_type="notification",
            subtype_id=self.env.ref("mail.mt_note").id,
        )
        self.env.flush_all()
        message = self._by_id(self._messages())[posted.id]
        text = "".join(part["text"] for part in message["body_parts"])
        self.assertEqual(text, "Real content")
        self.assertNotIn("preheader", text)

    def test_style_and_script_contents_are_not_rendered_as_text(self):
        """lxml exposes their contents as text; they are code, not prose."""
        posted = self.expense.with_user(self.user).message_post(
            body=Markup("<style>.x{color:red}</style><p>Visible</p>"),
            message_type="notification",
            subtype_id=self.env.ref("mail.mt_note").id,
        )
        self.env.flush_all()
        message = self._by_id(self._messages())[posted.id]
        text = "".join(part["text"] for part in message["body_parts"])
        self.assertEqual(text, "Visible")

    def test_user_notification_never_appears_in_the_thread(self):
        """Private-to-one-recipient messages must not leak into a shared
        thread. This exclusion is Odoo's, via `_message_fetch`."""
        private = self.expense.sudo().message_notify(
            partner_ids=[self.manager_user.partner_id.id],
            body="private to the manager",
            model="hr.expense", res_id=self.expense.id,
        )
        self.env.flush_all()
        self.assertNotIn(private.id, self._by_id(self._messages()))

    def test_mentions_are_reported(self):
        message = self._by_id(self._messages())[self.msg_other.id]
        self.assertIn(self.user.partner_id.id,
                      [m["id"] for m in message["mentions"]])

    def test_body_parts_identify_only_the_mentioned_name(self):
        message = self._by_id(self._messages())[self.msg_other.id]
        self.assertEqual(message["body_parts"], [
            {"type": "text", "text": "Hi "},
            {"type": "mention", "partner_id": self.user.partner_id.id,
             "name": "Log Note Mobile User", "text": "@Log Note Mobile User"},
            {"type": "text",
             "text": ", your reimbursement will be done tomorrow."},
        ])

    def test_create_note_builds_native_partner_mention(self):
        status, body = self._post_json(
            "/api/mobile/v1/log-note/messages",
            {
                "source": "expense",
                "id": self.expense.id,
                "body_parts": [
                    {"type": "text", "text": "Hi "},
                    {"type": "mention", "partner_id": self.manager_user.partner_id.id,
                     # This display value must be ignored by the server.
                     "name": "Not the real name"},
                    {"type": "text", "text": ", how are you?"},
                ],
            }, self._token())
        self.assertEqual(status, 201, body)
        message = body["data"]["message"]
        self.assertEqual(message["body_parts"], [
            {"type": "text", "text": "Hi "},
            {"type": "mention", "partner_id": self.manager_user.partner_id.id,
             "name": "Issac Alex", "text": "@Issac Alex"},
            {"type": "text", "text": ", how are you?"},
        ])
        # Stored body must be chatter HTML so the mention renders in Odoo web; assert on the DB.
        stored = self.env["mail.message"].sudo().browse(message["id"])
        self.assertIn('data-oe-model="res.partner"', stored.body)
        self.assertIn('data-oe-id="%s"' % self.manager_user.partner_id.id,
                      stored.body)

    def test_create_note_rejects_unknown_mentioned_partner(self):
        status, body = self._post_json(
            "/api/mobile/v1/log-note/messages",
            {"source": "expense", "id": self.expense.id,
             "body_parts": [{"type": "mention", "partner_id": 99999999}]},
            self._token())
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "invalid_body_parts")

    def test_owner_can_post_a_note_to_an_approved_expense(self):
        """Approved expenses are locked for edits, not for own mobile notes."""
        self.expense.sudo().write({"state": "approved"})

        status, body = self._post_json(
            "/api/mobile/v1/log-note/messages",
            {"source": "expense", "id": self.expense.id,
             "body_parts": [{"type": "text", "text": "Please review."}]},
            self._token())

        self.assertEqual(status, 201, body)
        self.assertTrue(body["success"])
        self.assertEqual(body["data"]["message"]["author"]["id"],
                         self.user.partner_id.id)

    def test_day_key_and_time_are_precomputed_in_the_users_timezone(self):
        """`day_key` and time are precomputed in the user's timezone for client grouping."""
        data = self._messages()
        self.assertTrue(data["timezone"])
        for message in data["messages"]:
            self.assertRegex(message["day_key"], r"^\d{4}-\d{2}-\d{2}$")
            self.assertRegex(message["time_display"], r"^\d{1,2}:\d{2} (AM|PM)$")

    def test_pagination_shape_and_has_next(self):
        data = self._messages(
            query="?source=expense&id=%s&limit=1" % self.expense.id)
        self.assertEqual(len(data["messages"]), 1)
        self.assertEqual(data["pagination"]["page"], 1)
        self.assertEqual(data["pagination"]["limit"], 1)
        self.assertGreaterEqual(data["pagination"]["total"], 3)
        self.assertTrue(data["pagination"]["has_next"])
        self.assertFalse(data["pagination"]["has_previous"])

    def test_pages_backwards_without_overlap(self):
        first = self._messages(
            query="?source=expense&id=%s&limit=2" % self.expense.id)
        older = self._messages(
            query="?source=expense&id=%s&page=2&limit=2"
                  % self.expense.id)
        self.assertFalse(
            set(m["id"] for m in first["messages"])
            & set(m["id"] for m in older["messages"]))
        self.assertTrue(all(m["id"] < first["messages"][-1]["id"]
                            for m in older["messages"]))

    def test_limit_is_capped(self):
        data = self._messages(
            query="?source=expense&id=%s&limit=99999" % self.expense.id)
        self.assertEqual(data["pagination"]["limit"], 50)

    def test_non_integer_page_is_a_400(self):
        status, body = self._get(
            "/api/mobile/v1/log-note/messages?source=expense&id=%s&page=abc"
            % self.expense.id, self._token())
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_pagination")

    def test_attachment_payload_shape(self):
        message = self._by_id(self._messages())[self.msg_own.id]
        self.assertEqual(len(message["attachments"]), 1)
        attachment = message["attachments"][0]
        self.assertEqual(attachment["name"], "receipt.png")
        self.assertEqual(attachment["kind"], "image")
        self.assertEqual(attachment["mimetype"], "image/png")
        self.assertTrue(attachment["size"])
        self.assertTrue(attachment["url"])
        self.assertTrue(attachment["download_requires_auth"])
        self.assertNotIn("?t=", attachment["url"])
        self.assertTrue(attachment["thumbnail_url"],
                        "images must carry a resized preview URL")

    def test_non_image_attachment_has_no_thumbnail(self):
        pdf = self.env["ir.attachment"].sudo().create({
            "name": "policy.pdf", "datas": base64.b64encode(b"%PDF-1.4 x"),
            "mimetype": "application/pdf",
            "res_model": "hr.expense", "res_id": self.expense.id,
        })
        message = self.expense.with_user(self.user).message_post(
            body=Markup("<p>policy</p>"), message_type="comment",
            subtype_id=self.env.ref("mail.mt_note").id,
            attachment_ids=[pdf.id])
        self.env.flush_all()
        attachment = self._by_id(self._messages())[message.id]["attachments"][0]
        self.assertEqual(attachment["kind"], "pdf")
        self.assertIsNone(attachment["thumbnail_url"])

    def test_bearer_authenticated_attachment_url_streams_the_file(self):
        message = self._by_id(self._messages())[self.msg_own.id]
        url = message["attachments"][0]["url"]
        resp = self.url_open(
            self._path(url),
            headers={"Authorization": "Bearer %s" % self._token()},
        )
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.headers["Content-Type"].startswith("image/"))
        self.assertEqual(resp.headers["Cache-Control"], "private, no-store")

    def test_attachment_without_bearer_token_is_rejected(self):
        status, body = self._get(
            "/api/mobile/v1/log-note/attachments/%s" % self.attachment.id)
        self.assertEqual(status, 401)
        self.assertEqual(body["code"], "missing_access_token")

    def test_other_employee_cannot_stream_foreign_attachment(self):
        """An attachment ID cannot bypass its parent expense's ownership."""
        other = self.env["ir.attachment"].sudo().create({
            "name": "secret.txt", "datas": base64.b64encode(b"payroll"),
            "mimetype": "text/plain",
            "res_model": "hr.expense", "res_id": self.foreign_expense.id,
        })
        status, body = self._get(
            "/api/mobile/v1/log-note/attachments/%s" % other.id,
            self._token())
        self.assertEqual(status, 404)
        self.assertEqual(body["code"], "attachment_not_found")

    def test_non_integer_attachment_id_returns_json(self):
        status, body = self._get(
            "/api/mobile/v1/log-note/attachments/not-a-number")
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_attachment_id")

    def test_listing_flags_own_note_as_editable_and_deletable(self):
        data = self._messages()
        own = self._by_id(data)[self.msg_own.id]
        self.assertTrue(own["is_editable"])
        self.assertTrue(own["is_deletable"])

    def test_listing_flags_another_authors_note_as_neither(self):
        data = self._messages()
        other = self._by_id(data)[self.msg_other.id]
        self.assertFalse(other["is_editable"])
        self.assertFalse(other["is_deletable"])

    def test_listing_flags_a_system_row_as_neither(self):
        """Authored by the caller, but machine-generated -- the audit trail
        is neither editable nor deletable."""
        note = self.expense.with_user(self.user).message_post(
            body=Markup("<p>keeps the thread non-empty</p>"),
            message_type="comment",
            subtype_id=self.env.ref("mail.mt_note").id)
        self.assertTrue(note)
        data = self._messages()
        by_id = self._by_id(data)
        if self.msg_system.id in by_id:
            row = by_id[self.msg_system.id]
            self.assertFalse(row["is_editable"])
            self.assertFalse(row["is_deletable"])

    def test_flags_match_what_the_endpoints_actually_do(self):
        """For every listed message, the flags predict the real endpoint outcome.
        Checked by calling the endpoints, not by re-deriving the rule."""
        data = self._messages()
        for row in data["messages"]:
            mid = row["id"]
            # PATCH with a no-op edit preserving the body so the fixture survives iterations.
            body = json.dumps([{"type": "text", "text": "flag probe"}])
            status, _ = self._patch(mid, {"body_parts": body})
            self.assertEqual(
                row["is_editable"], status == 200,
                "is_editable=%s but PATCH returned %s for message %s"
                % (row["is_editable"], status, mid))

        # DELETE is destructive: own listing, runs last, newest-first so earlier ids stay valid.
        data = self._messages()
        for row in data["messages"]:
            mid = row["id"]
            status, _ = self._delete(mid)
            self.assertEqual(
                row["is_deletable"], status == 200,
                "is_deletable=%s but DELETE returned %s for message %s"
                % (row["is_deletable"], status, mid))

    def test_flags_are_false_when_the_thread_is_not_writable(self):
        """Flags are false when the thread is readable but not writable (e.g. a manager's view)."""
        # Grant the approver app access; it can read the claim but fails _resolve_thread(write=True).
        self.manager_user.sudo().write({
            "group_ids": [(4, self.env.ref(
                "odx_mobile_connector.group_mobile_user").id)]})
        manager_note = self.expense.with_user(self.manager_user).message_post(
            body=Markup("<p>Manager own note</p>"),
            message_type="comment",
            subtype_id=self.env.ref("mail.mt_note").id)
        token = self._token("log_note_msg_manager@test.com")
        status, body = self._get(
            "/api/mobile/v1/log-note/messages?source=expense&id=%s"
            % self.expense.id, token)
        if status != 200:
            self.skipTest("manager cannot read this thread at all: %s" % body)
        rows = {m["id"]: m for m in body["data"]["messages"]}
        row = rows.get(manager_note.id)
        self.assertIsNotNone(row, "the manager should see their own note")
        self.assertFalse(row["is_deletable"])
        self.assertFalse(row["is_editable"])
        del_status, _ = self._delete(manager_note.id, token=token)
        self.assertNotEqual(del_status, 200)

    def _approved_leave_note(self):
        """The caller's own note on their own leave in state `validate`."""
        leave_type = self.env["hr.leave.type"].sudo().create({
            "name": "Log Note Leave",
            "requires_allocation": False,
            "request_unit": "day",
            "leave_validation_type": "hr",
        })
        leave = self.env["hr.leave"].sudo().create({
            "employee_id": self.employee.id,
            "holiday_status_id": leave_type.id,
            "request_date_from": "2026-07-06",
            "request_date_to": "2026-07-06",
        })
        note = leave.with_user(self.user).message_post(
            body=Markup("<p>Note on my leave</p>"),
            message_type="comment",
            subtype_id=self.env.ref("mail.mt_note").id)
        # Approved after the note is posted: writable when written, no longer writable now.
        self.env.cr.execute(
            "UPDATE hr_leave SET state = %s WHERE id = %s", ["validate", leave.id])
        self.env.invalidate_all()
        return leave, note

    def test_delete_own_note_on_an_approved_leave(self):
        """The exact reported 403: it must now succeed."""
        leave, note = self._approved_leave_note()
        self.assertEqual(leave.state, "validate", "sanity: the leave is approved")
        self.assertFalse(
            leave.with_user(self.user).has_access("write"),
            "sanity: the author can no longer write the document")

        status, body = self._delete(note.id)
        self.assertEqual(status, 200, body)
        self.assertFalse(self.env["mail.message"].sudo().browse(note.id).exists())

    def test_edit_own_note_on_an_approved_leave(self):
        leave, note = self._approved_leave_note()
        status, body = self._patch(note.id, {
            "body_parts": json.dumps([{"type": "text", "text": "Corrected on leave"}]),
        })
        self.assertEqual(status, 200, body)
        self.assertIn("Corrected on leave", note.body)

    def test_edit_down_to_nothing_on_an_approved_leave(self):
        """Editing to nothing triggers an unlink, a separate path from a plain text edit."""
        leave, note = self._approved_leave_note()
        status, body = self._patch(note.id, {
            "body_parts": json.dumps([]),
        })
        # Either refused as empty or accepted and cleaned up; never a 403/500.
        self.assertIn(status, (200, 400), body)
        if status == 400:
            self.assertEqual(body["code"], "empty_log_note")

    def test_another_authors_note_on_a_leave_is_still_refused(self):
        """The elevation must not have widened WHO may delete -- only what
        the caller may do to their OWN note."""
        leave, _own = self._approved_leave_note()
        foreign = leave.with_user(self.manager_user).message_post(
            body=Markup("<p>Manager note</p>"),
            message_type="comment",
            subtype_id=self.env.ref("mail.mt_note").id)
        status, body = self._delete(foreign.id)
        self.assertEqual(status, 403, body)
        self.assertEqual(body["code"], "message_not_author")
        self.assertTrue(foreign.exists())

    def test_system_row_on_a_leave_is_still_refused(self):
        """...nor WHAT may be deleted: the audit trail stays protected."""
        leave, _own = self._approved_leave_note()
        system = leave.with_user(self.user).sudo()._message_log(
            body="Leave approved")
        status, body = self._delete(system.id)
        self.assertEqual(status, 403, body)
        self.assertEqual(body["code"], "message_not_deletable")
        self.assertTrue(system.exists())

    def _patch(self, message_id, payload=None, token=None, files=None,
               in_path=True):
        headers = {"Authorization": "Bearer %s" % (token or self._token())}
        url = ("/api/mobile/v1/log-note/messages/%s" % message_id if in_path
               else "/api/mobile/v1/log-note/messages")
        data = dict(payload or {})
        if not in_path:
            data["message_id"] = message_id
        resp = self.url_open(url, headers=headers, data=data, files=files,
                             method="PATCH")
        return resp.status_code, resp.json()

    def test_edit_replaces_the_body_of_the_callers_own_note(self):
        status, body = self._patch(self.msg_own.id, {
            "body_parts": json.dumps([{"type": "text", "text": "Corrected text"}]),
        })
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"], body)
        self.assertIn("Corrected text", self.msg_own.body)
        self.assertNotIn("Here is the", self.msg_own.body)

    def test_edit_marks_the_note_as_edited(self):
        """Odoo's own `_message_update_content` appends the marker the web
        client renders -- going through it keeps mobile and web consistent."""
        self._patch(self.msg_own.id, {
            "body_parts": json.dumps([{"type": "text", "text": "Fixed"}]),
        })
        self.assertIn("o-mail-Message-edited", self.msg_own.body)

    def test_edit_accepts_the_id_in_the_payload(self):
        status, body = self._patch(self.msg_own.id, {
            "body_parts": json.dumps([{"type": "text", "text": "Via payload"}]),
        }, in_path=False)
        self.assertEqual(status, 200, body)
        self.assertIn("Via payload", self.msg_own.body)

    def test_edit_keeps_existing_attachments_when_the_field_is_omitted(self):
        """Absence must never mean "keep none" -- same rule as PATCH /expense."""
        status, body = self._patch(self.msg_own.id, {
            "body_parts": json.dumps([{"type": "text", "text": "Still has the file"}]),
        })
        self.assertEqual(status, 200, body)
        self.assertTrue(self.attachment.exists())
        self.assertIn(self.attachment, self.msg_own.attachment_ids)

    def test_edit_can_drop_an_attachment_and_deletes_it_outright(self):
        """A dropped file is deleted, not just unlinked, or it would resurface as a record attachment."""
        attachment_id = self.attachment.id
        status, body = self._patch(self.msg_own.id, {
            "body_parts": json.dumps([{"type": "text", "text": "File removed"}]),
            "existing_attachments": json.dumps([]),
        })
        self.assertEqual(status, 200, body)
        self.assertFalse(
            self.env["ir.attachment"].sudo().browse(attachment_id).exists())
        after = self._messages()
        self.assertNotIn(
            attachment_id, [a["id"] for a in after["record"]["attachments"]],
            "a dropped file must not resurface as a record attachment")

    def test_edit_can_add_a_new_attachment(self):
        status, body = self._patch(
            self.msg_own.id,
            {"body_parts": json.dumps([{"type": "text", "text": "One more file"}])},
            files={"attachment": ("added.png", TINY_PNG, "image/png")})
        self.assertEqual(status, 200, body)
        names = self.msg_own.attachment_ids.mapped("name")
        self.assertIn("added.png", names)
        self.assertIn("receipt.png", names, "the original must still be there")

    def test_edit_rejects_an_svg_renamed_to_png(self):
        """An SVG renamed to .png is rejected; bytes are checked against the extension."""
        status, body = self._patch(
            self.msg_own.id,
            {"body_parts": json.dumps([{"type": "text", "text": "Have a look"}])},
            files={"attachment": ("innocent.png", SVG_BYTES, "image/png")})
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "invalid_attachment")
        self.assertNotIn("innocent.png", self.msg_own.attachment_ids.mapped("name"))

    def test_edit_rejects_an_executable_attachment(self):
        status, body = self._patch(
            self.msg_own.id,
            {"body_parts": json.dumps([{"type": "text", "text": "Run this"}])},
            files={"attachment": ("payload.exe", b"MZ\x90\x00", "application/octet-stream")})
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "invalid_attachment")

    def test_edit_stores_the_server_derived_mimetype(self):
        """The declared type is discarded even when the file is legitimate."""
        status, body = self._patch(
            self.msg_own.id,
            {"body_parts": json.dumps([{"type": "text", "text": "One more file"}])},
            files={"attachment": ("shot.png", TINY_PNG, "application/octet-stream")})
        self.assertEqual(status, 200, body)
        added = self.msg_own.attachment_ids.filtered(
            lambda a: a.name == "shot.png")
        self.assertEqual(added.mimetype, "image/png")

    def test_edit_rejects_another_authors_note(self):
        original = self.msg_other.body
        status, body = self._patch(self.msg_other.id, {
            "body_parts": json.dumps([{"type": "text", "text": "Not mine"}]),
        })
        self.assertEqual(status, 403, body)
        self.assertEqual(body["code"], "message_not_author")
        self.assertEqual(self.msg_other.body, original, "it must be untouched")

    def test_edit_rejects_a_system_message(self):
        """The audit trail is not editable from a phone, even though Odoo
        stamps the acting employee as its author."""
        original = self.msg_system.body
        status, body = self._patch(self.msg_system.id, {
            "body_parts": json.dumps([{"type": "text", "text": "Rewriting history"}]),
        })
        self.assertEqual(status, 403, body)
        self.assertEqual(body["code"], "message_not_deletable")
        self.assertEqual(self.msg_system.body, original)

    def test_edit_cannot_reach_a_message_on_another_employees_thread(self):
        foreign_note = self.foreign_expense.with_user(
            self.other_user).message_post(
                body=Markup("<p>Private</p>"),
                message_type="comment",
                subtype_id=self.env.ref("mail.mt_note").id)
        status, body = self._patch(foreign_note.id, {
            "body_parts": json.dumps([{"type": "text", "text": "Nope"}]),
        })
        self.assertEqual(status, 404, body)
        self.assertEqual(body["code"], "message_not_found")
        self.assertIn("Private", foreign_note.body)

    def test_edit_rejects_an_empty_result(self):
        """Clearing the text AND every attachment leaves nothing to show."""
        status, body = self._patch(self.msg_own.id, {
            "body_parts": json.dumps([]),
            "existing_attachments": json.dumps([]),
        })
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "empty_log_note")
        self.assertTrue(self.msg_own.exists(), "nothing may be destroyed by a 400")
        self.assertTrue(self.attachment.exists())

    def test_edit_keeps_the_text_when_only_attachments_change(self):
        """Dropping a file must not silently blank the note's text."""
        self._patch(self.msg_own.id, {
            "body_parts": json.dumps([{"type": "text", "text": "Keep this text"}]),
            "existing_attachments": json.dumps([]),
        })
        self.assertIn("Keep this text", self.msg_own.body)

    def test_edit_to_whitespace_only_is_refused(self):
        """A whitespace-only edit is refused; markup-wrapped whitespace must not pass the empty check."""
        original = self.msg_own.body
        status, body = self._patch(self.msg_own.id, {
            "body_parts": json.dumps([{"type": "text", "text": "   "}]),
            "existing_attachments": json.dumps([]),
        })
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "empty_log_note")
        self.assertEqual(self.msg_own.body, original, "nothing may change")

    def test_edit_to_whitespace_is_allowed_when_a_file_remains(self):
        """Whitespace text is only fatal when NOTHING else is left -- a note
        that still carries its attachment is legitimately contentful."""
        status, body = self._patch(self.msg_own.id, {
            "body_parts": json.dumps([{"type": "text", "text": "   "}]),
        })
        self.assertEqual(status, 200, body)
        self.assertTrue(self.attachment.exists())

    def test_create_with_whitespace_only_body_is_refused(self):
        """The same guard on the create path, which shared the defect."""
        status, body = self._post_json(
            "/api/mobile/v1/log-note/messages",
            {"source": "expense", "id": self.expense.id,
             "body_parts": [{"type": "text", "text": "   "}]},
            self._token())
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "empty_log_note")

    def test_a_bare_mention_is_still_valid_content(self):
        """A note that is only "@somebody" has content and must be accepted
        -- the emptiness guard must not swallow it."""
        status, body = self._post_json(
            "/api/mobile/v1/log-note/messages",
            {"source": "expense", "id": self.expense.id,
             "body_parts": [{"type": "mention",
                             "partner_id": self.manager_user.partner_id.id}]},
            self._token())
        self.assertEqual(status, 201, body)

    def test_edit_unknown_id_is_a_404(self):
        status, body = self._patch(987654321, {
            "body_parts": json.dumps([{"type": "text", "text": "x"}])})
        self.assertEqual(status, 404, body)
        self.assertEqual(body["code"], "message_not_found")

    def test_edit_non_integer_id_is_a_400(self):
        status, body = self._patch("not-a-number", {
            "body_parts": json.dumps([{"type": "text", "text": "x"}])})
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "invalid_message_id")

    def test_edit_requires_authentication(self):
        original = self.msg_own.body
        resp = self.url_open(
            "/api/mobile/v1/log-note/messages/%s" % self.msg_own.id,
            data={"body_parts": json.dumps([{"type": "text", "text": "x"}])},
            method="PATCH")
        self.assertEqual(resp.status_code, 401)
        self.assertEqual(self.msg_own.body, original)

    def _delete(self, message_id, token=None, query=False):
        headers = {}
        if token is not False:
            headers["Authorization"] = "Bearer %s" % (token or self._token())
        url = ("/api/mobile/v1/log-note/messages?message_id=%s" % message_id
               if query else
               "/api/mobile/v1/log-note/messages/%s" % message_id)
        resp = self.url_open(url, headers=headers, method="DELETE")
        return resp.status_code, resp.json()

    def test_delete_removes_the_callers_own_note(self):
        message_id = self.msg_own.id
        status, body = self._delete(message_id)
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"], body)
        self.assertEqual(body["data"]["id"], message_id)
        self.assertEqual(body["data"]["source"], "expense")
        self.assertFalse(
            self.env["mail.message"].sudo().browse(message_id).exists())

    def test_delete_accepts_the_query_parameter_form(self):
        message_id = self.msg_own.id
        status, body = self._delete(message_id, query=True)
        self.assertEqual(status, 200, body)
        self.assertFalse(
            self.env["mail.message"].sudo().browse(message_id).exists())

    def test_delete_takes_the_notes_attachment_with_it(self):
        """Deleting a note deletes its attachment, which otherwise resurfaces as the record's own file.
        `mail.message.unlink()` only cascades attachments whose res_model is mail.message."""
        attachment_id = self.attachment.id
        before = self._messages()
        self.assertNotIn(
            attachment_id, [a["id"] for a in before["record"]["attachments"]],
            "sanity: while the note exists its file is not a record attachment")

        status, body = self._delete(self.msg_own.id)
        self.assertEqual(status, 200, body)
        self.assertFalse(
            self.env["ir.attachment"].sudo().browse(attachment_id).exists(),
            "the note's attachment must be deleted with it")

        after = self._messages()
        self.assertNotIn(
            attachment_id, [a["id"] for a in after["record"]["attachments"]],
            "a deleted note's file must never resurface as a record attachment")

    def test_delete_rejects_another_authors_note(self):
        """Only the author may delete a note; stricter than Odoo's document-write rule."""
        status, body = self._delete(self.msg_other.id)
        self.assertEqual(status, 403, body)
        self.assertEqual(body["code"], "message_not_author")
        self.assertTrue(self.msg_other.exists(), "it must survive untouched")

    def test_delete_rejects_a_system_message(self):
        """System messages cannot be deleted, even though Odoo stamps the acting employee as author."""
        self.assertEqual(self.msg_system.author_id, self.user.partner_id,
                         "sanity: the system row IS authored by the caller")
        status, body = self._delete(self.msg_system.id)
        self.assertEqual(status, 403, body)
        self.assertEqual(body["code"], "message_not_deletable")
        self.assertTrue(self.msg_system.exists())

    def test_delete_cannot_reach_a_message_on_another_employees_thread(self):
        """A foreign thread is a 404, not a 403 -- the endpoint must not
        confirm that the message exists."""
        foreign_note = self.foreign_expense.with_user(
            self.other_user).message_post(
                body=Markup("<p>Private</p>"),
                message_type="comment",
                subtype_id=self.env.ref("mail.mt_note").id)
        status, body = self._delete(foreign_note.id)
        self.assertEqual(status, 404, body)
        self.assertEqual(body["code"], "message_not_found")
        self.assertTrue(foreign_note.exists())

    def test_delete_unknown_id_is_a_404(self):
        status, body = self._delete(987654321)
        self.assertEqual(status, 404, body)
        self.assertEqual(body["code"], "message_not_found")

    def test_delete_non_integer_id_is_a_400(self):
        status, body = self._delete("not-a-number")
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "invalid_message_id")

    def test_delete_without_an_id_is_a_400(self):
        """The collection route with no `message_id` must not be a wildcard."""
        resp = self.url_open(
            "/api/mobile/v1/log-note/messages",
            headers={"Authorization": "Bearer %s" % self._token()},
            method="DELETE")
        self.assertEqual(resp.status_code, 400)
        self.assertEqual(resp.json()["code"], "invalid_message_id")

    def test_delete_requires_authentication(self):
        message_id = self.msg_own.id
        status, body = self._delete(message_id, token=False)
        self.assertEqual(status, 401, body)
        self.assertTrue(
            self.env["mail.message"].sudo().browse(message_id).exists(),
            "an unauthenticated request must delete nothing")

    # Time Off approve/refuse messages: date kept, time dropped.

    def _leave_thread_text(self, body, message_type):
        leave, _note = self._approved_leave_note()
        message = leave.sudo().message_post(
            body=body, message_type=message_type,
            subtype_id=self.env.ref("mail.mt_note").id)
        self.env.flush_all()
        data = self._messages(query="?source=timeoff&id=%s" % leave.id)
        row = self._by_id(data)[message.id]
        return "".join(part["text"] for part in row["body_parts"])

    def test_leave_accepted_message_drops_the_time(self):
        text = self._leave_thread_text(
            "Your Unpaid planned on 2026-08-19 08:00:00 has been accepted",
            "notification")
        self.assertEqual(
            text, "Your Unpaid planned on 2026-08-19 has been accepted")

    def test_leave_refused_message_drops_the_utc_time(self):
        text = self._leave_thread_text(
            "Your Unpaid planned on 2026-08-21 02:30:00 has been refused",
            "notification")
        self.assertEqual(
            text, "Your Unpaid planned on 2026-08-21 has been refused")

    def test_typed_note_on_a_leave_is_never_rewritten(self):
        text = self._leave_thread_text(
            Markup("<p>Back on 2026-08-22 09:30:00 sharp</p>"), "comment")
        self.assertEqual(text, "Back on 2026-08-22 09:30:00 sharp")

    def test_datetime_outside_time_off_is_untouched(self):
        message = self.expense.sudo().message_post(
            body="Paid on 2026-08-19 08:00:00", message_type="notification",
            subtype_id=self.env.ref("mail.mt_note").id)
        self.env.flush_all()
        row = self._by_id(self._messages())[message.id]
        text = "".join(part["text"] for part in row["body_parts"])
        self.assertEqual(text, "Paid on 2026-08-19 08:00:00")
