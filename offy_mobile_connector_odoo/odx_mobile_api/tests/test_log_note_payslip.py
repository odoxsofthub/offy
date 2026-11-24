from odoo.tests import HttpCase, tagged

PASSWORD = "log_note_payslip_pw_1234"
LOGIN = "log_note_payslip_user@test.com"


@tagged("-at_install", "post_install")
class TestMobileLogNotePayslip(HttpCase):
    """Payslip chatter through `/log-note/messages`.
    Employees cannot read `hr.payslip`, so message access cannot be derived from the document."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.user = Users.create({
            "name": "Log Note Payslip User",
            "login": LOGIN,
            "password": PASSWORD,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Log Note Payslip User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })
        cls.other_user = Users.create({
            "name": "Other Payslip User",
            "login": "log_note_payslip_other@test.com",
            "password": PASSWORD,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.other_employee = Employee.create({
            "name": "Other Payslip User",
            "company_id": company.id,
            "user_id": cls.other_user.id,
        })

        cls.payslip = cls._make_payslip("Payslip Chatter Test", cls.employee)
        # Belongs to somebody else -- the IDOR target.
        cls.foreign_payslip = cls._make_payslip("Not yours", cls.other_employee)

        # Internal log note (notification, mt_note) as HR posts it on a payslip.
        cls.admin_note = cls.payslip._message_log(body="Payslip validated by HR")
        cls.admin_note.sudo().write({"author_id": cls.env.ref("base.user_admin").partner_id.id})


    @classmethod
    def _make_payslip(cls, name, employee):
        """A payslip in a mobile-visible state, set by SQL to skip the payroll compute."""
        payslip = cls.env["hr.payslip"].sudo().create({
            "name": name,
            "employee_id": employee.id,
        })
        cls.env.cr.execute(
            "UPDATE hr_payslip SET state = 'validated' WHERE id = %s",
            [payslip.id])
        cls.env.invalidate_all()
        return payslip

    def _token(self, login=LOGIN):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": login, "password": PASSWORD},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"]

    def _messages(self, token, payslip_id):
        resp = self.url_open(
            "/api/mobile/v1/log-note/messages"
            "?source=payslip&id=%s&page=1&limit=30" % payslip_id,
            headers={"Authorization": "Bearer %s" % token},
        )
        return resp.status_code, resp.json()

    def test_admin_log_notes_are_returned(self):
        """HR's internal log notes on the caller's payslip are returned."""
        token = self._token()
        status, body = self._messages(token, self.payslip.id)
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"], body)

        # The body is delivered as ordered `body_parts`, not a flat string.
        bodies = [
            "".join(part.get("text") or "" for part in m["body_parts"])
            for m in body["data"]["messages"]
        ]
        self.assertTrue(
            any("Payslip validated by HR" in b for b in bodies),
            "the HR log note is missing from the payslip chatter: %s" % bodies)

    def test_total_matches_the_messages_returned(self):
        """`total` must describe the same set the caller receives."""
        token = self._token()
        _, body = self._messages(token, self.payslip.id)
        self.assertEqual(
            body["data"]["pagination"]["total"],
            len(body["data"]["messages"]),
            "pagination total disagrees with the rows served")

    def test_another_employees_payslip_is_still_not_readable(self):
        token = self._token()
        status, body = self._messages(token, self.foreign_payslip.id)
        self.assertEqual(status, 404, body)
        self.assertFalse(body["success"])

    def test_unknown_payslip_id_is_not_found(self):
        token = self._token()
        status, body = self._messages(token, 999999999)
        self.assertEqual(status, 404, body)

    def test_requires_authentication(self):
        resp = self.url_open(
            "/api/mobile/v1/log-note/messages?source=payslip&id=%s" % self.payslip.id)
        self.assertEqual(resp.status_code, 401)

    def _post_note(self, token, payslip_id, text="hello from mobile"):
        import json
        resp = self.url_open(
            "/api/mobile/v1/log-note/messages",
            data={
                "source": "payslip",
                "id": payslip_id,
                "body_parts": json.dumps([{"type": "text", "text": text}]),
            },
            method="POST",
            headers={"Authorization": "Bearer %s" % token},
        )
        try:
            return resp.status_code, resp.json()
        except ValueError:
            return resp.status_code, {"raw": resp.text[:200]}

    def test_posting_a_note_on_own_payslip_is_not_forbidden(self):
        """A payslip the caller may open must also accept their own note."""
        token = self._token()
        status, body = self._post_note(token, self.payslip.id)
        self.assertNotEqual(
            status, 403,
            "posting to a payslip the caller owns must not be forbidden: %s" % body)
        self.assertIn(status, (200, 201), body)

    def test_posting_to_another_employees_payslip_is_not_found(self):
        token = self._token()
        status, body = self._post_note(token, self.foreign_payslip.id)
        self.assertEqual(status, 404, body)

    def test_feature_not_linked_is_the_only_403(self):
        """Unlinking the payslip feature is what legitimately yields 403 (deny-by-default gate)."""
        feature = self.env["mobile.feature"].sudo().search(
            [("code", "=", "payslip")], limit=1)
        links = self.env["mobile.user.feature"].sudo().search(
            [("user_id", "=", self.user.id), ("feature_id", "=", feature.id)])
        links.unlink()
        token = self._token()
        status, body = self._messages(token, self.payslip.id)
        self.assertEqual(status, 403, body)
        self.assertEqual(body["code"], "payslip_access_denied")
