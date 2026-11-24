import base64
import json

from odoo.tests import HttpCase, tagged

TINY_PNG_BYTES = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
)
# A scripted SVG -- the payload the upload allowlist exists to keep out.
SVG_BYTES = (b"<svg xmlns='http://www.w3.org/2000/svg'>"
             b"<script>alert(document.domain)</script></svg>")


# url_open() sends GET unless `data` is truthy; the submit endpoint needs a dummy body.
SUBMIT_BODY = {"_": "1"}


@tagged("-at_install", "post_install")
class TestMobileExpenseApi(HttpCase):
    """Tests for the mobile expense screens: summary, categories, list, create."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        Product = cls.env["product.product"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        company = cls.env.ref("base.main_company")

        cls.category = Product.create({
            "name": "Travel",
            "type": "service",
            "can_be_expensed": True,
        })
        cls.other_category = Product.create({
            "name": "Meals",
            "type": "service",
            "can_be_expensed": True,
        })
        cls.non_expense_product = Product.create({
            "name": "Not Expensable",
            "type": "service",
            "can_be_expensed": False,
        })

        # Auto-submit needs an approver, else hr_expense _check_can_approve rejects auto-validation.
        approver_group = cls.env.ref("hr_expense.group_hr_expense_team_approver")
        cls.manager_user = Users.create({
            "name": "Expense Approver",
            "login": "expense_api_manager@test.com",
            "password": "expense_api_pw_1234",
            "group_ids": [(4, cls.env.ref("base.group_user").id), (4, approver_group.id)],
        })
        cls.manager_employee = Employee.create({
            "name": "Expense Approver",
            "company_id": company.id,
            "user_id": cls.manager_user.id,
        })

        cls.user = Users.create({
            "name": "Expense Mobile User",
            "login": "expense_api_user@test.com",
            "password": "expense_api_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, cls.env.ref("base.group_user").id)],
        })
        cls.employee = Employee.create({
            "name": "Expense Mobile User",
            "company_id": company.id,
            "user_id": cls.user.id,
            "parent_id": cls.manager_employee.id,
        })

        cls.other_user = Users.create({
            "name": "Other Expense User",
            "login": "expense_api_other@test.com",
            "password": "expense_api_pw_1234",
            "group_ids": [(4, mobile_group.id)],
        })
        cls.other_employee = Employee.create({
            "name": "Other Expense User",
            "company_id": company.id,
            "user_id": cls.other_user.id,
        })

        # No manager, expense_manager_id or department, so `_can_be_autovalidated()` is true.
        cls.no_approver_user = Users.create({
            "name": "No Approver Expense User",
            "login": "expense_api_noapprover@test.com",
            "password": "expense_api_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, cls.env.ref("base.group_user").id)],
        })
        cls.no_approver_employee = Employee.create({
            "name": "No Approver Expense User",
            "company_id": company.id,
            "user_id": cls.no_approver_user.id,
        })

        # Same as no_approver_user but an administrator: base.group_system decides auto-approve vs draft.
        cls.no_approver_admin = Users.create({
            "name": "No Approver Expense Admin",
            "login": "expense_api_noapprover_admin@test.com",
            "password": "expense_api_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, cls.env.ref("base.group_user").id),
                          (4, cls.env.ref("base.group_system").id)],
        })
        cls.no_approver_admin_employee = Employee.create({
            "name": "No Approver Expense Admin",
            "company_id": company.id,
            "user_id": cls.no_approver_admin.id,
        })

        cls.user_no_employee = Users.create({
            "name": "No Employee Expense User",
            "login": "expense_api_noemp@test.com",
            "password": "expense_api_pw_1234",
            "group_ids": [(4, mobile_group.id)],
        })

        cls.user_not_mobile = Users.create({
            "name": "Non Mobile Expense User",
            "login": "expense_api_nonmobile@test.com",
            "password": "expense_api_pw_1234",
            "group_ids": [(4, cls.env.ref("base.group_user").id)],
        })

        # A few historical expenses for pagination/summary checks.
        Expense = cls.env["hr.expense"].sudo()
        cls.expenses = Expense
        for i in range(5):
            cls.expenses |= Expense.create({
                "name": "Client meeting coffee %d" % i,
                "employee_id": cls.employee.id,
                "product_id": cls.category.id,
                "quantity": 1,
                "total_amount_currency": 32.10,
                "date": "2026-06-%02d" % (10 + i),
                "payment_mode": "own_account",
            })

        # Belongs to another employee -- must never leak into cls.user's data.
        Expense.create({
            "name": "Other user's lunch",
            "employee_id": cls.other_employee.id,
            "product_id": cls.other_category.id,
            "quantity": 1,
            "total_amount_currency": 15.0,
            "date": "2026-06-20",
            "payment_mode": "own_account",
        })

    def _token_for(self, login, password):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": login, "password": password},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login unexpectedly failed: %s" % body)
        return body["data"]["token"]

    def _get(self, path, token):
        resp = self.url_open(path, headers={"Authorization": "Bearer %s" % token})
        return resp.status_code, resp.json()

    def _post(self, path, token, data, files=None):
        """POST as multipart/form-data (urlencoded when files is None), like the mobile client.
        Files go under the ``file`` field name."""
        resp = self.url_open(
            path,
            headers={"Authorization": "Bearer %s" % token},
            data=data, files=files,
        )
        return resp.status_code, resp.json()

    def test_non_mobile_user_is_rejected_at_login(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": "expense_api_nonmobile@test.com",
                  "password": "expense_api_pw_1234"},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "mobile_access_denied")

    def test_user_without_employee_gets_safe_error(self):
        """A token whose employee was unlinked after login gets a clean 404, not a crash."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        self.employee.write({"user_id": False})
        self.env.flush_all()
        self.addCleanup(self.employee.write, {"user_id": self.user.id})
        status, body = self._get("/api/mobile/v1/expense/summary", token)
        self.assertEqual(status, 404)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "employee_not_found")

    def test_summary_returns_pending_reimbursement_amount(self):
        # Drafts are never reimbursable, so the fixtures must be submitted to count as pending.
        self.env.cr.execute(
            "UPDATE hr_expense SET state = 'submitted' WHERE id IN %s", [tuple(self.expenses.ids)])
        self.env.invalidate_all()
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._get("/api/mobile/v1/expense/summary", token)
        self.assertEqual(status, 200)
        data = body["data"]
        self.assertEqual(data["pending_count"], 5)
        self.assertAlmostEqual(data["pending_reimbursement_amount"], 5 * 32.10, places=2)
        self.assertIn("average_approval_time", data)
        self.assertEqual(data["average_approval_time"]["unit"], "business_days")

    def test_summary_recent_expenses_returns_only_three(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._get("/api/mobile/v1/expense/summary", token)
        self.assertEqual(status, 200)
        self.assertEqual(len(body["data"]["recent_expenses"]), 3)

    def test_summary_does_not_expose_other_employee_expenses(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._get("/api/mobile/v1/expense/summary", token)
        self.assertEqual(status, 200)
        titles = [e["title"] for e in body["data"]["recent_expenses"]]
        self.assertNotIn("Other user's lunch", titles)

    def test_categories_come_from_backend_configuration(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._get("/api/mobile/v1/expense/categories", token)
        self.assertEqual(status, 200)
        names = {c["name"] for c in body["data"]}
        self.assertIn("Travel", names)
        self.assertIn("Meals", names)
        self.assertNotIn("Not Expensable", names)
        self.assertNotIn("requires_receipt", body["data"][0])

    def test_list_pagination_metadata(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._get("/api/mobile/v1/expense?page=1&limit=2", token)
        self.assertEqual(status, 200)
        pagination = body["data"]["pagination"]
        self.assertEqual(pagination["page"], 1)
        self.assertEqual(pagination["limit"], 2)
        self.assertEqual(pagination["total"], 5)
        self.assertTrue(pagination["has_next"])
        self.assertFalse(pagination["has_previous"])
        self.assertEqual(
            sum(len(g["expenses"]) for g in body["data"]["groups"]), 2)

    def test_list_does_not_expose_other_employee_expenses(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._get("/api/mobile/v1/expense?limit=50", token)
        self.assertEqual(status, 200)
        titles = [e["title"] for g in body["data"]["groups"]
                  for e in g["expenses"]]
        self.assertNotIn("Other user's lunch", titles)
        self.assertEqual(len(titles), 5)

    def test_create_expense_validates_amount(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 0,
            "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_amount")

    def test_create_expense_validates_category(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 32.10,
            "category_id": self.non_expense_product.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_category")

    def test_create_expense_validates_date(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 32.10,
            "category_id": self.category.id,
            "expense_date": "not-a-date",
        })
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_date")

    def test_create_expense_links_to_current_employee(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 32.10,
            "category_id": self.category.id,
            "expense_date": "2026-06-29",
            "description": "Client meeting coffee",
        })
        self.assertEqual(status, 200)
        self.assertTrue(body["success"])
        expense = self.env["hr.expense"].sudo().browse(body["data"]["id"])
        self.assertEqual(expense.employee_id, self.employee)
        # Creating submits by default; with a resolvable approver the state is `submitted` -> `pending`.
        self.assertEqual(body["data"]["status"], "pending")

    def test_create_expense_ignores_client_supplied_employee_id(self):
        """employee_id/user_id in the payload must never be honored."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 10.0,
            "category_id": self.category.id,
            "expense_date": "2026-06-29",
            "employee_id": self.other_employee.id,
            "user_id": self.other_user.id,
        })
        self.assertEqual(status, 200)
        expense = self.env["hr.expense"].sudo().browse(body["data"]["id"])
        self.assertEqual(expense.employee_id, self.employee)

    def test_create_expense_with_receipt_creates_safe_attachment(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post(
            "/api/mobile/v1/expense", token,
            data={
                "amount": 20.0,
                "category_id": self.category.id,
                "expense_date": "2026-06-29",
            },
            files={"file": ("receipt.png", TINY_PNG_BYTES, "image/png")},
        )
        self.assertEqual(status, 200)
        expense = self.env["hr.expense"].sudo().browse(body["data"]["id"])
        self.assertEqual(len(expense.attachment_ids), 1)
        attachment = expense.attachment_ids[0]
        self.assertEqual(attachment.res_model, "hr.expense")
        self.assertEqual(attachment.res_id, expense.id)
        self.assertEqual(attachment.mimetype, "image/png")

    def test_create_expense_with_multiple_receipts(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post(
            "/api/mobile/v1/expense", token,
            data={
                "amount": 15.0,
                "category_id": self.category.id,
                "expense_date": "2026-06-29",
            },
            files=[
                ("file", ("receipt1.png", TINY_PNG_BYTES, "image/png")),
                ("file", ("receipt2.png", TINY_PNG_BYTES, "image/png")),
            ],
        )
        self.assertEqual(status, 200)
        expense = self.env["hr.expense"].sudo().browse(body["data"]["id"])
        self.assertEqual(len(expense.attachment_ids), 2)

    def test_create_expense_rejects_invalid_receipt_mimetype(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post(
            "/api/mobile/v1/expense", token,
            data={
                "amount": 20.0,
                "category_id": self.category.id,
                "expense_date": "2026-06-29",
            },
            files={"file": ("malware.exe", b"not a real exe",
                                      "application/x-msdownload")},
        )
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_receipt")

    def test_create_expense_rejects_svg_receipt(self):
        """SVG receipts are refused outright: served inline, an SVG can carry script."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post(
            "/api/mobile/v1/expense", token,
            data={
                "amount": 20.0,
                "category_id": self.category.id,
                "expense_date": "2026-06-29",
            },
            files={"file": ("receipt.svg", SVG_BYTES, "image/svg+xml")},
        )
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "invalid_receipt")

    def test_create_expense_rejects_svg_renamed_to_png(self):
        """The magic bytes decide, not the file name or declared Content-Type."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post(
            "/api/mobile/v1/expense", token,
            data={
                "amount": 20.0,
                "category_id": self.category.id,
                "expense_date": "2026-06-29",
            },
            files={"file": ("receipt.png", SVG_BYTES, "image/png")},
        )
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "invalid_receipt")

    def test_create_expense_accepts_receipt_sent_as_octet_stream(self):
        """Uploads declared as `application/octet-stream` (as Flutter sends) are stored under the real type."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post(
            "/api/mobile/v1/expense", token,
            data={
                "amount": 20.0,
                "category_id": self.category.id,
                "expense_date": "2026-06-29",
            },
            files={"file": ("receipt.png", TINY_PNG_BYTES, "application/octet-stream")},
        )
        self.assertEqual(status, 200, body)
        expense = self.env["hr.expense"].sudo().browse(body["data"]["id"])
        self.assertEqual(expense.attachment_ids.mapped("mimetype"), ["image/png"])

    def test_create_expense_missing_optional_fields_does_not_crash(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 5.5,
            "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 200)
        self.assertTrue(body["success"])

    def _unlink_expense_feature(self):
        """Deny the Expense feature by removing the user's link row."""
        feature = self.env.ref("odx_mobile_connector.feature_expense")
        self.env["mobile.user.feature"].sudo().search([
            ("user_id", "=", self.user.id),
            ("feature_id", "=", feature.id),
        ]).unlink()

    def test_unlinked_feature_denies_summary(self):
        self._unlink_expense_feature()
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._get("/api/mobile/v1/expense/summary", token)
        self.assertEqual(status, 403)
        self.assertEqual(body["code"], "expense_access_denied")

    def test_unlinked_feature_denies_create(self):
        self._unlink_expense_feature()
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 10.0,
            "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 403)
        self.assertEqual(body["code"], "expense_access_denied")

    def test_linked_feature_allows_both_read_and_create(self):
        """A linked feature is full access — there is no read-only level."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, _ = self._get("/api/mobile/v1/expense/summary", token)
        self.assertEqual(status, 200)

        status, _ = self._post("/api/mobile/v1/expense", token, {
            "amount": 10.0,
            "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertNotEqual(status, 403)

    def _create_expense(self, token, **overrides):
        """Create an expense as a draft (`submit=false`, since create submits by default)."""
        payload = {
            "amount": 21.5,
            "category_id": self.category.id,
            "expense_date": "2026-06-29",
            "submit": "false",
        }
        payload.update(overrides)
        status, body = self._post("/api/mobile/v1/expense", token, payload)
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"], body)
        return body["data"]

    def test_create_submits_by_default_and_reports_the_real_state(self):
        """Create submits by default and returns Odoo's computed state (`submitted` -> `pending`)."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 200, body)
        data = body["data"]
        self.assertEqual(data["status"], "pending")
        self.assertEqual(data["status_display"], "Pending")
        self.assertFalse(data["can_submit"])
        expense = self.env["hr.expense"].sudo().browse(data["id"])
        self.assertEqual(expense.state, "submitted")

    def test_no_approver_admin_is_auto_approved(self):
        """An administrator with no approver configured still auto-approves, as in core."""
        token = self._token_for(
            "expense_api_noapprover_admin@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 200, body)
        data = body["data"]
        self.assertEqual(data["status"], "approved")
        self.assertEqual(data["status_display"], "Approved")
        expense = self.env["hr.expense"].sudo().browse(data["id"])
        self.assertEqual(expense.state, "approved")

    def test_no_approver_regular_user_is_pending_not_approved(self):
        """A regular user with no approver configured is submitted (pending), neither self-approved nor draft."""
        token = self._token_for(
            "expense_api_noapprover@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 200, body)
        data = body["data"]
        self.assertEqual(data["status"], "pending")
        self.assertEqual(data["status_display"], "Pending")
        self.assertFalse(data["can_submit"],
                         "it is already submitted; there is nothing left to send")
        self.assertNotIn("submit_error", data)
        expense = self.env["hr.expense"].sudo().browse(data["id"])
        self.assertEqual(expense.state, "submitted")
        self.assertEqual(expense.approval_state, "submitted")
        self.assertFalse(
            expense.approval_date,
            "nothing approved it, so there must be no approval date")

    def test_no_approver_claim_is_still_approvable_by_a_human(self):
        """A submitted claim with no `manager_id` can still be approved by a human."""
        token = self._token_for(
            "expense_api_noapprover@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 200, body)
        expense = self.env["hr.expense"].sudo().browse(body["data"]["id"])
        self.assertFalse(expense.manager_id, "sanity: nobody is assigned")

        officer = self.env["res.users"].sudo().create({
            "name": "Expense HR Officer",
            "login": "expense_api_officer@test.com",
            "group_ids": [
                (4, self.env.ref("base.group_user").id),
                (4, self.env.ref("hr_expense.group_hr_expense_manager").id),
            ],
        })
        expense.with_user(officer).action_approve()
        self.assertEqual(expense.state, "approved")

    def test_editing_a_no_approver_claim_does_not_approve_it(self):
        """Editing a no-approver claim resubmits it as pending, not auto-approved."""
        token = self._token_for(
            "expense_api_noapprover@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 200, body)
        expense = self.env["hr.expense"].sudo().browse(body["data"]["id"])
        self.assertEqual(expense.state, "submitted")

        status, body = self._patch(token, {
            "id": expense.id,
            "amount": 99.0, "category_id": self.category.id,
            "expense_date": "2026-06-29", "description": "edited",
        })
        self.assertEqual(status, 200, body)
        self.assertEqual(body["data"]["status"], "pending", body)
        self.assertEqual(expense.state, "submitted")
        self.assertEqual(expense.total_amount_currency, 99.0)

    def test_no_approver_rule_turns_only_on_admin_rights(self):
        """The no-approver rule turns only on `base.group_system`; fixtures differ in nothing else."""
        payload = {"amount": 21.5, "category_id": self.category.id,
                   "expense_date": "2026-06-29"}
        _, regular = self._post(
            "/api/mobile/v1/expense",
            self._token_for("expense_api_noapprover@test.com", "expense_api_pw_1234"),
            dict(payload))
        _, admin = self._post(
            "/api/mobile/v1/expense",
            self._token_for("expense_api_noapprover_admin@test.com",
                            "expense_api_pw_1234"),
            dict(payload))
        self.assertEqual(regular["data"]["status"], "pending")
        self.assertEqual(admin["data"]["status"], "approved")

    def test_employee_who_is_their_own_approver_still_auto_approves(self):
        """An employee who is their own Work Manager still auto-approves, as in core."""
        self.no_approver_employee.sudo().write(
            {"parent_id": self.no_approver_employee.id})
        token = self._token_for(
            "expense_api_noapprover@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 200, body)
        self.assertEqual(body["data"]["status"], "approved")

    def test_submit_endpoint_on_a_saved_draft_does_not_self_approve(self):
        """The standalone submit endpoint applies the same no-approver rule as create."""
        token = self._token_for(
            "expense_api_noapprover@test.com", "expense_api_pw_1234")
        _, created = self._post("/api/mobile/v1/expense", token, {
            "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29", "submit": "false",
        })
        self.assertEqual(created["data"]["status"], "draft")
        status, body = self._post(
            "/api/mobile/v1/expense/%s/submit" % created["data"]["id"],
            token, SUBMIT_BODY)
        self.assertEqual(status, 200, body)
        expense = self.env["hr.expense"].sudo().browse(created["data"]["id"])
        self.assertEqual(expense.state, "submitted")

    def test_create_with_submit_false_still_saves_a_draft(self):
        """The opt-out: a caller that genuinely wants a draft can still have
        one, and it really has not entered the approval flow."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29", "submit": "false",
        })
        self.assertEqual(status, 200, body)
        data = body["data"]
        self.assertEqual(data["status"], "draft")
        self.assertEqual(data["status_display"], "Draft")
        self.assertTrue(data["can_submit"])
        expense = self.env["hr.expense"].sudo().browse(data["id"])
        self.assertEqual(expense.state, "draft")
        self.assertFalse(
            expense.approval_state,
            "submit=false must not enter the approval flow at all")

    def test_submit_endpoint_advances_a_draft(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        data = self._create_expense(token)
        status, body = self._post(
            "/api/mobile/v1/expense/%s/submit" % data["id"], token, SUBMIT_BODY)
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"], body)
        expense = self.env["hr.expense"].sudo().browse(data["id"])
        self.assertNotEqual(
            expense.state, "draft",
            "submitting must hand the claim on, exactly as the backend button does")

    def test_submitting_twice_is_reported_not_raised(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        data = self._create_expense(token)
        path = "/api/mobile/v1/expense/%s/submit" % data["id"]
        self._post(path, token, SUBMIT_BODY)
        status, body = self._post(path, token, SUBMIT_BODY)
        self.assertEqual(status, 409)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "expense_not_draft")

    def test_submit_cannot_reach_another_employees_expense(self):
        """An id from the client must never resolve outside the caller."""
        other = self.env["hr.expense"].sudo().create({
            "name": "Not yours",
            "employee_id": self.other_employee.id,
            "product_id": self.other_category.id,
            "quantity": 1,
            "total_amount_currency": 5.0,
            "date": "2026-06-29",
            "payment_mode": "own_account",
        })
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post(
            "/api/mobile/v1/expense/%s/submit" % other.id, token, SUBMIT_BODY)
        self.assertEqual(status, 404)
        self.assertEqual(body["code"], "expense_not_found")
        self.assertEqual(other.state, "draft", "the other claim must be untouched")

    def test_submit_rejects_a_non_numeric_id(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense/abc/submit", token, SUBMIT_BODY)
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_expense_id")

    def test_submit_requires_authentication(self):
        resp = self.url_open("/api/mobile/v1/expense/1/submit", data=SUBMIT_BODY)
        self.assertEqual(resp.status_code, 401)

    def _patch(self, token, data, files=None):
        resp = self.url_open(
            "/api/mobile/v1/expense",
            headers={"Authorization": "Bearer %s" % token},
            data=data, files=files, method="PATCH",
        )
        return resp.status_code, resp.json()

    def _delete(self, token, expense_id, path="/api/mobile/v1/expenses"):
        resp = self.url_open(
            "%s/%s" % (path, expense_id),
            headers={"Authorization": "Bearer %s" % token},
            method="DELETE",
        )
        return resp.status_code, resp.json()

    def test_delete_removes_a_draft_expense(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        self.assertTrue(expense.exists())

        status, body = self._delete(token, created["id"])
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"], body)
        self.assertEqual(body["data"]["id"], created["id"])
        self.assertFalse(expense.exists(), "the expense must really be gone")

    def test_delete_also_works_on_the_singular_path(self):
        """Both registered paths hit the same handler."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        status, body = self._delete(token, created["id"],
                                    path="/api/mobile/v1/expense")
        self.assertEqual(status, 200, body)
        self.assertFalse(
            self.env["hr.expense"].sudo().browse(created["id"]).exists())

    def test_delete_cleans_up_receipts_and_chatter_attachments(self):
        """Deleting an expense removes its receipts and chatter attachments, which core leaves behind."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        receipt = self._attach(expense, "receipt.png")
        chatter = self._attach_via_log_note(expense, "log_note_file.png")
        message_ids = expense.message_ids.ids
        self.assertTrue(message_ids, "sanity: the log note exists")

        status, body = self._delete(token, created["id"])
        self.assertEqual(status, 200, body)
        self.assertFalse(receipt.exists(), "the receipt must be cleaned up")
        self.assertFalse(chatter.exists(),
                         "the chatter attachment must be cleaned up too")
        self.assertFalse(
            self.env["mail.message"].sudo().browse(message_ids).exists(),
            "log notes must go with the record")
        self.assertFalse(
            self.env["ir.attachment"].sudo().search([
                ("res_model", "=", "hr.expense"),
                ("res_id", "=", created["id"]),
            ]), "no attachment row may be left pointing at the deleted expense")

    def test_delete_withdraws_and_removes_a_submitted_expense(self):
        """A pending claim is withdrawn to draft via `action_reset()`, then removed."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        self._post("/api/mobile/v1/expense/%s/submit" % created["id"],
                   token, SUBMIT_BODY)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        self.assertEqual(expense.state, "submitted", "sanity: it is pending")

        status, body = self._delete(token, created["id"])
        self.assertEqual(status, 200, body)
        self.assertFalse(expense.exists(), "the expense must really be gone")

    def test_delete_rejects_an_approved_expense(self):
        """Past `submitted` there is no route: an employee cannot reset an
        approved claim, and `_unlink_except_approved` refuses it anyway."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        self._post("/api/mobile/v1/expense/%s/submit" % created["id"],
                   token, SUBMIT_BODY)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        expense.write({"approval_state": "approved"})
        self.assertEqual(expense.state, "approved")

        status, body = self._delete(token, created["id"])
        self.assertEqual(status, 409, body)
        self.assertEqual(body["code"], "expense_not_deletable")
        self.assertIn("status", body["data"])
        self.assertTrue(expense.exists(), "a rejected delete must change nothing")

    def test_delete_cannot_reach_another_employees_expense(self):
        """A foreign id is a 404, not a 403 -- the endpoint must not reveal
        whether somebody else's expense exists."""
        other = self.env["hr.expense"].sudo().create({
            "name": "Not yours",
            "employee_id": self.other_employee.id,
            "product_id": self.other_category.id,
            "quantity": 1, "total_amount_currency": 5.0,
            "date": "2026-06-29", "payment_mode": "own_account",
        })
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._delete(token, other.id)
        self.assertEqual(status, 404, body)
        self.assertEqual(body["code"], "expense_not_found")
        self.assertTrue(other.exists(), "the other employee's claim is untouched")

    def test_delete_unknown_id_is_a_404(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._delete(token, 987654321)
        self.assertEqual(status, 404, body)
        self.assertEqual(body["code"], "expense_not_found")

    def test_delete_rejects_a_non_numeric_id(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._delete(token, "abc")
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "invalid_expense_id")

    def test_delete_requires_authentication(self):
        created_id = self._create_expense(
            self._token_for("expense_api_user@test.com", "expense_api_pw_1234"))["id"]
        resp = self.url_open("/api/mobile/v1/expenses/%s" % created_id,
                             method="DELETE")
        self.assertEqual(resp.status_code, 401)
        self.assertTrue(
            self.env["hr.expense"].sudo().browse(created_id).exists(),
            "an unauthenticated request must delete nothing")

    def test_patch_updates_the_editable_fields(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token, amount=21.5, description="Coffee")
        status, body = self._patch(token, {
            "id": created["id"],
            "amount": "1000.0",
            "category_id": self.category.id,
            "expense_date": "2026-09-01",
            "description": "Communication",
        })
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"], body)

        expense = self.env["hr.expense"].sudo().browse(created["id"])
        self.assertEqual(expense.total_amount_currency, 1000.0)
        self.assertEqual(expense.name, "Communication")
        self.assertEqual(str(expense.date), "2026-09-01")
        self.assertEqual(expense.state, "draft",
                         "editing must not advance the expense's state")

    def test_patch_adds_a_receipt_without_removing_existing_ones(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        pre_existing = self.env["ir.attachment"].sudo().create({
            "name": "already_there.png",
            "datas": base64.b64encode(TINY_PNG_BYTES),
            "mimetype": "image/png",
            "res_model": "hr.expense", "res_id": expense.id,
        })
        status, body = self._patch(
            token,
            {"id": expense.id, "amount": 21.5, "category_id": self.category.id,
             "expense_date": "2026-06-29"},
            files={"file": ("new_receipt.png", TINY_PNG_BYTES, "image/png")},
        )
        self.assertEqual(status, 200, body)
        names = expense.attachment_ids.mapped("name")
        self.assertIn("already_there.png", names)
        self.assertIn("new_receipt.png", names)

    def _attach(self, expense, name):
        return self.env["ir.attachment"].sudo().create({
            "name": name,
            "datas": base64.b64encode(TINY_PNG_BYTES),
            "mimetype": "image/png",
            "res_model": "hr.expense", "res_id": expense.id,
        })

    def test_omitting_existing_attachments_keeps_everything(self):
        """Absence must not mean 'keep none' -- every prior caller of this
        endpoint predates this field and must see no change in behaviour."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        self._attach(expense, "keep_me.png")

        status, body = self._patch(token, {
            "id": expense.id, "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 200, body)
        self.assertIn("keep_me.png", expense.attachment_ids.mapped("name"))

    def test_existing_attachments_deletes_the_ones_left_out(self):
        """An id missing from the array is removed."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        keep = self._attach(expense, "keep.png")
        drop = self._attach(expense, "drop.png")

        status, body = self._patch(token, {
            "id": expense.id, "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
            "existing_attachments": json.dumps([keep.id]),
        })
        self.assertEqual(status, 200, body)
        names = expense.attachment_ids.mapped("name")
        self.assertIn("keep.png", names)
        self.assertNotIn("drop.png", names)
        self.assertFalse(drop.exists(), "the dropped attachment must actually be deleted")

    def test_existing_attachments_empty_array_deletes_all_of_them(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        self._attach(expense, "a.png")
        self._attach(expense, "b.png")

        status, body = self._patch(token, {
            "id": expense.id, "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
            "existing_attachments": json.dumps([]),
        })
        self.assertEqual(status, 200, body)
        self.assertFalse(expense.attachment_ids)

    def test_existing_attachments_and_new_files_in_the_same_request(self):
        """Deletion and addition together, independent of each other."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        keep = self._attach(expense, "keep.png")
        self._attach(expense, "drop.png")

        status, body = self._patch(
            token,
            {"id": expense.id, "amount": 21.5, "category_id": self.category.id,
             "expense_date": "2026-06-29",
             "existing_attachments": json.dumps([keep.id])},
            files={"file": ("brand_new.png", TINY_PNG_BYTES, "image/png")},
        )
        self.assertEqual(status, 200, body)
        names = expense.attachment_ids.mapped("name")
        self.assertEqual(sorted(names), ["brand_new.png", "keep.png"])

    def test_existing_attachments_ignores_a_foreign_id(self):
        """An id naming someone else's attachment must be a harmless no-op --
        never a way to delete a record outside this expense."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        keep = self._attach(expense, "keep.png")
        other_expense = self.env["hr.expense"].sudo().create({
            "name": "Someone else's",
            "employee_id": self.other_employee.id,
            "product_id": self.other_category.id,
            "quantity": 1, "total_amount_currency": 5.0,
            "date": "2026-06-29", "payment_mode": "own_account",
        })
        foreign = self._attach(other_expense, "not_yours.png")

        status, body = self._patch(token, {
            "id": expense.id, "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
            "existing_attachments": json.dumps([keep.id, foreign.id]),
        })
        self.assertEqual(status, 200, body)
        self.assertIn("keep.png", expense.attachment_ids.mapped("name"))
        self.assertTrue(foreign.exists(), "another record's attachment must survive untouched")
        self.assertEqual(foreign.res_id, other_expense.id)

    def test_existing_attachments_rejects_malformed_input(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        status, body = self._patch(token, {
            "id": created["id"], "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
            "existing_attachments": "not-json",
        })
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_existing_attachments")

    def test_existing_attachments_rejects_a_non_array(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        status, body = self._patch(token, {
            "id": created["id"], "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
            "existing_attachments": json.dumps({"not": "a list"}),
        })
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_existing_attachments")

    def test_kept_plus_new_still_respects_the_receipt_cap(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        kept_ids = []
        for i in range(5):
            kept_ids.append(self._attach(expense, "receipt_%d.png" % i).id)

        status, body = self._patch(
            token,
            {"id": expense.id, "amount": 21.5, "category_id": self.category.id,
             "expense_date": "2026-06-29",
             "existing_attachments": json.dumps(kept_ids)},
            files={"file": ("one_more.png", TINY_PNG_BYTES, "image/png")},
        )
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "too_many_receipts")
        # Nothing must have been deleted by a request that was rejected.
        self.assertEqual(len(expense.attachment_ids), 5)

    def test_deleting_the_main_attachment_reassigns_the_preview(self):
        """The receipt preview must not silently vanish when other receipts
        still exist -- only the specific one requested for deletion is gone."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        main = self._attach(expense, "main.png")
        other = self._attach(expense, "other.png")
        expense.sudo()._message_set_main_attachment_id(main, force=True)
        self.assertEqual(expense.message_main_attachment_id, main)

        status, body = self._patch(token, {
            "id": expense.id, "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
            "existing_attachments": json.dumps([other.id]),
        })
        self.assertEqual(status, 200, body)
        self.assertEqual(expense.message_main_attachment_id, other,
                         "the surviving receipt should become the new preview")

    def _attach_via_log_note(self, expense, name):
        """Attach a file via `message_post`; it lands in `expense.attachment_ids` like a receipt."""
        attachment = self._attach(expense, name)
        expense.sudo().message_post(
            body="a log note with a file",
            message_type="comment",
            subtype_id=self.env.ref("mail.mt_note").id,
            attachment_ids=[attachment.id],
        )
        return attachment

    def test_existing_attachments_never_deletes_a_log_note_attachment(self):
        """`existing_attachments` never deletes a log-note attachment, which the client never saw."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        keep = self._attach(expense, "keep.png")
        drop = self._attach(expense, "drop.png")
        chatter = self._attach_via_log_note(expense, "log_note_file.png")

        status, body = self._patch(token, {
            "id": expense.id, "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
            "existing_attachments": json.dumps([keep.id]),
        })
        self.assertEqual(status, 200, body)
        self.assertTrue(keep.exists(), "the kept receipt must survive")
        self.assertFalse(drop.exists(), "the receipt left out must still be deleted")
        self.assertTrue(
            chatter.exists(),
            "a log note's attachment must never be deleted by this field")
        self.assertIn("log_note_file.png", expense.attachment_ids.mapped("name"))

    def test_empty_existing_attachments_spares_log_note_attachments(self):
        """`[]` means 'keep no RECEIPTS' -- not 'wipe the chatter too'."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        receipt = self._attach(expense, "receipt.png")
        chatter = self._attach_via_log_note(expense, "log_note_file.png")

        status, body = self._patch(token, {
            "id": expense.id, "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
            "existing_attachments": json.dumps([]),
        })
        self.assertEqual(status, 200, body)
        self.assertFalse(receipt.exists(), "every receipt should be gone")
        self.assertTrue(chatter.exists(), "the log note's file must remain")
        self.assertEqual(expense.attachment_ids, chatter)

    def test_omitting_existing_attachments_leaves_log_note_attachments_alone(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        receipt = self._attach(expense, "receipt.png")
        chatter = self._attach_via_log_note(expense, "log_note_file.png")

        status, body = self._patch(token, {
            "id": expense.id, "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 200, body)
        self.assertTrue(receipt.exists())
        self.assertTrue(chatter.exists())

    def test_log_note_attachments_do_not_count_against_the_receipt_cap(self):
        """The cap is a RECEIPT budget. Chatter files are not receipts, so a
        busy discussion must not stop an employee attaching a receipt."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        kept_ids = [self._attach(expense, "receipt_%d.png" % i).id for i in range(4)]
        for i in range(3):
            self._attach_via_log_note(expense, "chat_%d.png" % i)

        status, body = self._patch(
            token,
            {"id": expense.id, "amount": 21.5, "category_id": self.category.id,
             "expense_date": "2026-06-29",
             "existing_attachments": json.dumps(kept_ids)},
            files={"file": ("one_more.png", TINY_PNG_BYTES, "image/png")},
        )
        self.assertEqual(status, 200, body)
        names = expense.attachment_ids.mapped("name")
        self.assertIn("one_more.png", names)
        for i in range(3):
            self.assertIn("chat_%d.png" % i, names)

    def test_patch_only_touches_what_log_note_offered_as_record_attachments(self):
        """The attachments the client is shown and those PATCH may delete are the same set.
        Asserted against the real `/log-note/messages` response."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        receipt = self._attach(expense, "receipt.png")
        self._attach_via_log_note(expense, "log_note_file.png")

        status, listed = self._get(
            "/api/mobile/v1/log-note/messages?source=expense&id=%s" % expense.id,
            token)
        self.assertEqual(status, 200, listed)
        offered_ids = {a["id"] for a in listed["data"]["record"]["attachments"]}
        self.assertEqual(offered_ids, {receipt.id},
                         "only the receipt should ever be offered as removable")

        # Sending back exactly what was offered must change nothing at all.
        status, body = self._patch(token, {
            "id": expense.id, "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29",
            "existing_attachments": json.dumps(sorted(offered_ids)),
        })
        self.assertEqual(status, 200, body)
        self.assertEqual(len(expense.attachment_ids), 2,
                         "echoing back the offered list must delete nothing")

    def test_patch_cannot_reach_another_employees_expense(self):
        other = self.env["hr.expense"].sudo().create({
            "name": "Not yours",
            "employee_id": self.other_employee.id,
            "product_id": self.other_category.id,
            "quantity": 1,
            "total_amount_currency": 5.0,
            "date": "2026-06-29",
            "payment_mode": "own_account",
        })
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._patch(token, {
            "id": other.id, "amount": 999, "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 404)
        self.assertEqual(body["code"], "expense_not_found")
        self.assertEqual(other.total_amount_currency, 5.0, "the other claim must be untouched")

    def _listed(self, token, expense_id):
        status, body = self._get("/api/mobile/v1/expense?page=1&limit=50", token)
        self.assertEqual(status, 200, body)
        rows = [e for g in body["data"]["groups"] for e in g["expenses"]]
        return next(r for r in rows if r["id"] == expense_id)

    def test_flags_on_a_draft_expense(self):
        """Draft: both actions available."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        self.assertTrue(created["is_editable"], "create response")
        self.assertTrue(created["is_deletable"], "create response")
        row = self._listed(token, created["id"])
        self.assertTrue(row["is_editable"])
        self.assertTrue(row["is_deletable"])

    def test_flags_on_a_submitted_expense(self):
        """Pending: BOTH true. The endpoint withdraws the claim with Odoo's
        own `action_reset()` first, so edit and delete are both reachable."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created, _expense = self._submitted_expense(token)
        row = self._listed(token, created["id"])
        self.assertTrue(row["is_editable"])
        self.assertTrue(row["is_deletable"])

    def test_flags_on_an_approved_expense(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created, expense = self._submitted_expense(token)
        expense.write({"approval_state": "approved"})
        row = self._listed(token, created["id"])
        self.assertFalse(row["is_editable"])
        self.assertFalse(row["is_deletable"])

    def test_expense_flags_match_what_the_endpoints_actually_do(self):
        """For each state, the expense flags predict the real outcome of calling the endpoints."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")

        for build in (lambda: (self._create_expense(token), None),
                      lambda: self._submitted_expense(token)):
            created, _e = build()
            row = self._listed(token, created["id"])
            status, _body = self._patch(token, {
                "id": created["id"], "amount": 31.0,
                "category_id": self.category.id, "expense_date": "2026-06-29",
            })
            self.assertEqual(
                row["is_editable"], status == 200,
                "is_editable=%s but PATCH returned %s" % (row["is_editable"], status))

        created = self._create_expense(token)
        row = self._listed(token, created["id"])
        status, _ = self._delete(token, created["id"])
        self.assertEqual(row["is_deletable"], status == 200)

        created, _expense = self._submitted_expense(token)
        row = self._listed(token, created["id"])
        status, _ = self._delete(token, created["id"])
        self.assertEqual(
            row["is_deletable"], status == 200,
            "is_deletable=%s but DELETE returned %s" % (row["is_deletable"], status))

    def _submitted_expense(self, token):
        created = self._create_expense(token)
        self._post("/api/mobile/v1/expense/%s/submit" % created["id"],
                   token, SUBMIT_BODY)
        expense = self.env["hr.expense"].sudo().browse(created["id"])
        self.assertEqual(expense.state, "submitted", "sanity: it is pending")
        return created, expense

    def test_patch_edits_a_submitted_expense_and_resubmits_it(self):
        """A pending claim is editable: the endpoint withdraws it, applies
        the edit and hands it straight back to the same approver."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created, expense = self._submitted_expense(token)
        approver_before = expense.manager_id

        status, body = self._patch(token, {
            "id": created["id"], "amount": 999, "category_id": self.category.id,
            "expense_date": "2026-06-29", "description": "corrected",
        })
        self.assertEqual(status, 200, body)
        self.assertEqual(expense.total_amount_currency, 999,
                         "the edit must actually have been applied")
        self.assertEqual(expense.state, "submitted",
                         "it must end up back with the approver, not in draft")
        self.assertEqual(expense.manager_id, approver_before,
                         "manager_id survives the reset -- same approver")
        self.assertEqual(body["data"]["status"], "pending")
        self.assertFalse(body["data"]["can_submit"])

    def test_a_failed_edit_leaves_the_claim_with_its_approver(self):
        """The withdraw/edit/resubmit is one unit. If any part fails the
        claim must NOT be stranded in draft, out of the approver's queue."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created, expense = self._submitted_expense(token)
        amount_before = expense.total_amount_currency

        status, body = self._patch(token, {
            "id": created["id"], "amount": 555,
            "category_id": self.non_expense_product.id,
            "expense_date": "2026-06-29",
        })
        self.assertNotEqual(status, 200, body)
        self.assertEqual(expense.state, "submitted",
                         "the claim must still be with its approver")
        self.assertEqual(expense.total_amount_currency, amount_before,
                         "and completely unedited")

    def test_patch_rejects_an_approved_expense(self):
        """Past `submitted` an employee cannot reset, so there is no honest
        way to edit."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created, expense = self._submitted_expense(token)
        expense.write({"approval_state": "approved"})
        self.assertEqual(expense.state, "approved")

        status, body = self._patch(token, {
            "id": created["id"], "amount": 999, "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 409, body)
        self.assertEqual(body["code"], "expense_not_editable")
        self.assertNotEqual(expense.total_amount_currency, 999)

    def test_patch_rejects_invalid_amount(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        created = self._create_expense(token)
        status, body = self._patch(token, {
            "id": created["id"], "amount": "not-a-number",
            "category_id": self.category.id, "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_amount")

    def test_patch_rejects_a_non_numeric_id(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._patch(token, {
            "id": "abc", "amount": 10, "category_id": self.category.id,
            "expense_date": "2026-06-29",
        })
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_expense_id")

    def test_patch_requires_authentication(self):
        resp = self.url_open(
            "/api/mobile/v1/expense",
            data={"id": 1, "amount": 10}, method="PATCH")
        self.assertEqual(resp.status_code, 401)

    def test_omitting_the_flag_behaves_exactly_like_submit_true(self):
        """The default is not merely "usually submits" -- omitting the field
        and sending `submit=true` must be the same request."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        base = {"amount": 21.5, "category_id": self.category.id,
                "expense_date": "2026-06-29"}
        _, omitted = self._post("/api/mobile/v1/expense", token, dict(base))
        _, explicit = self._post("/api/mobile/v1/expense", token,
                                 dict(base, submit="true"))
        self.assertEqual(omitted["data"]["status"], explicit["data"]["status"])
        self.assertEqual(omitted["data"]["can_submit"],
                         explicit["data"]["can_submit"])
        self.assertNotIn("submit_error", omitted["data"])

    def test_create_with_submit_true_submits_for_approval(self):
        """An employee WITH a resolvable approver: submitted, not approved."""
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        data = self._create_expense(token, submit="true")
        self.assertEqual(data["status"], "pending")
        self.assertFalse(data["can_submit"])
        self.assertNotIn("submit_error", data)
        expense = self.env["hr.expense"].sudo().browse(data["id"])
        self.assertEqual(expense.state, "submitted")

    def test_create_with_submit_true_auto_approves_when_odoo_would(self):
        """No approver configured -> approved for an administrator, per Odoo's `_can_be_autovalidated()`."""
        token = self._token_for(
            "expense_api_noapprover_admin@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29", "submit": "true",
        })
        self.assertEqual(status, 200, body)
        data = body["data"]
        self.assertEqual(data["status"], "approved")
        self.assertFalse(data["can_submit"])
        expense = self.env["hr.expense"].sudo().browse(data["id"])
        self.assertEqual(expense.state, "approved")

    def test_explicit_submit_true_does_not_bypass_the_no_approver_rule(self):
        """A regular user cannot self-approve by asking explicitly -- the
        rule is about who may approve, not about which field was sent."""
        token = self._token_for(
            "expense_api_noapprover@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29", "submit": "true",
        })
        self.assertEqual(status, 200, body)
        self.assertEqual(body["data"]["status"], "pending")

    def test_create_with_submit_false_opts_out_of_the_approval_flow(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        data = self._create_expense(token, submit="false")
        self.assertEqual(data["status"], "draft")
        self.assertTrue(data["can_submit"])

    def test_create_rejects_an_unrecognised_submit_value(self):
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post("/api/mobile/v1/expense", token, {
            "amount": 21.5, "category_id": self.category.id,
            "expense_date": "2026-06-29", "submit": "maybe",
        })
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_submit_flag")

    def test_submit_reports_a_failure_without_destroying_the_record(self):
        """A submit failure reports an error and leaves the record unchanged.
        Runs through the HTTP endpoint because the savepoint needs a request; the row is built directly."""
        expense = self.env["hr.expense"].sudo().create({
            "name": "No category",
            "employee_id": self.employee.id,
            "quantity": 1,
            "total_amount_currency": 10.0,
            "date": "2026-06-29",
            "payment_mode": "own_account",
        })
        token = self._token_for("expense_api_user@test.com", "expense_api_pw_1234")
        status, body = self._post(
            "/api/mobile/v1/expense/%s/submit" % expense.id, token, SUBMIT_BODY)
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "expense_submit_failed")
        self.assertTrue(expense.exists())
        self.assertEqual(expense.state, "draft",
                         "a submit failure must leave the record exactly as it was")
