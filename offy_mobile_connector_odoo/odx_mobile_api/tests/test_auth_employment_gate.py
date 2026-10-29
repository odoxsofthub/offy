from odoo.tests import HttpCase, tagged


@tagged("-at_install", "post_install")
class TestMobileAuthEmploymentGate(HttpCase):
    """A mobile user with no employee record must be refused at login."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        Company = cls.env["res.company"].sudo()
        cls.mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        cls.base_group = cls.env.ref("base.group_user")
        cls.company = cls.env.ref("base.main_company")
        cls.password = "employment_gate_pw_1234"

        cls.user_no_employee = Users.create({
            "name": "Gate No Employee",
            "login": "gate_no_employee@test.com",
            "password": cls.password,
            "group_ids": [(4, cls.base_group.id), (4, cls.mobile_group.id)],
        })

        # Mobile user with an employee -- the control.
        cls.user_employed = Users.create({
            "name": "Gate Employed",
            "login": "gate_employed@test.com",
            "password": cls.password,
            "group_ids": [(4, cls.base_group.id), (4, cls.mobile_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Gate Employed",
            "company_id": cls.company.id,
            "user_id": cls.user_employed.id,
        })

        # Employed only in a second company: a company-scoped check at login would wrongly lock them out.
        cls.other_company = Company.create({"name": "Gate Other Company"})
        cls.user_other_company = Users.create({
            "name": "Gate Other Company User",
            "login": "gate_other_company@test.com",
            "password": cls.password,
            "company_id": cls.company.id,
            "company_ids": [(6, 0, [cls.company.id, cls.other_company.id])],
            "group_ids": [(4, cls.base_group.id), (4, cls.mobile_group.id)],
        })
        cls.other_company_employee = Employee.create({
            "name": "Gate Other Company User",
            "company_id": cls.other_company.id,
            "user_id": cls.user_other_company.id,
        })

        cls.env.flush_all()

    def _login(self, login, password=None):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": login, "password": password or self.password},
            headers={"Content-Type": "application/json"},
        )
        return resp.status_code, resp.json()

    def test_login_without_employee_is_refused(self):
        status, body = self._login("gate_no_employee@test.com")
        self.assertEqual(status, 403, body)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "employee_not_linked")
        self.assertEqual(
            body["message"], "No employee is linked to this mobile user.")

    def test_refused_login_issues_no_token(self):
        """The whole point: no signed-in state to reach a dead end from."""
        _, body = self._login("gate_no_employee@test.com")
        self.assertNotIn("token", body.get("data") or {})
        self.assertNotIn("refreshToken", body.get("data") or {})

    def test_login_with_employee_still_succeeds(self):
        status, body = self._login("gate_employed@test.com")
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"])
        self.assertTrue(body["data"]["token"])

    def test_employment_in_a_non_default_company_still_logs_in(self):
        """The check must not be company-scoped; no company is selected at login."""
        status, body = self._login("gate_other_company@test.com")
        self.assertEqual(status, 200, body)
        self.assertTrue(body["data"]["token"])

    def test_archived_employee_does_not_count_as_employment(self):
        """An offboarded employee whose user was left active loses access."""
        self.employee.action_archive()
        self.env.flush_all()
        try:
            status, body = self._login("gate_employed@test.com")
            self.assertEqual(status, 403, body)
            self.assertEqual(body["code"], "employee_not_linked")
        finally:
            self.employee.action_unarchive()
            self.env.flush_all()

    def test_wrong_password_still_reports_invalid_credentials(self):
        """A bad password must fail as a credential error, not reveal employment status."""
        status, body = self._login("gate_no_employee@test.com", "wrong-password")
        self.assertEqual(status, 401)
        self.assertEqual(body["code"], "invalid_credentials")

    def test_refresh_is_refused_once_employment_is_removed(self):
        """Unlinking the employee must stop refresh from minting new access tokens."""
        _, body = self._login("gate_employed@test.com")
        refresh_token = body["data"]["refreshToken"]

        self.employee.write({"user_id": False})
        self.env.flush_all()
        try:
            resp = self.url_open(
                "/api/mobile/v1/auth/refresh",
                json={"refreshToken": refresh_token},
                headers={"Content-Type": "application/json"},
            )
            self.assertEqual(resp.status_code, 403, resp.text)
            self.assertEqual(resp.json()["code"], "employee_not_linked")
        finally:
            self.employee.write({"user_id": self.user_employed.id})
            self.env.flush_all()

    def test_refresh_still_works_while_employed(self):
        _, body = self._login("gate_employed@test.com")
        resp = self.url_open(
            "/api/mobile/v1/auth/refresh",
            json={"refreshToken": body["data"]["refreshToken"]},
            headers={"Content-Type": "application/json"},
        )
        self.assertEqual(resp.status_code, 200, resp.text)
        self.assertTrue(resp.json()["data"]["token"])
