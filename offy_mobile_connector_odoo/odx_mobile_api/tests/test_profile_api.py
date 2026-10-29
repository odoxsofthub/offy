import json
import base64

from odoo.tests import HttpCase, tagged


@tagged("-at_install", "post_install")
class TestMobileProfileApi(HttpCase):
    """Tests for GET /api/mobile/v1/profile and its avatar endpoints.
    Uses real HTTP through /auth/login so the full token stack is exercised."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        # group_mobile_user is not implied by group_user; grant it or the user is 'share' with no ACL.
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.manager_emp = Employee.create({
            "name": "Test Manager",
            "company_id": company.id,
            "work_email": "manager@test.com",
        })

        # Primary user: reports to manager_emp; not an HR Officer, so no hr.group_hr_user dependence.
        cls.user = Users.create({
            "name": "Mobile Employee",
            "login": "profile_api_user@test.com",
            "password": "profile_api_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Mobile Employee",
            "company_id": company.id,
            "user_id": cls.user.id,
            "parent_id": cls.manager_emp.id,
        })

        # A peer reporting to the same manager -- must appear in "team".
        cls.peer_emp = Employee.create({
            "name": "Peer Employee",
            "company_id": company.id,
            "parent_id": cls.manager_emp.id,
        })

        # Unrelated employee: must never appear in team nor via the avatar endpoint.
        cls.unrelated_emp = Employee.create({
            "name": "Unrelated Employee",
            "company_id": company.id,
        })

        cls.user_no_employee = Users.create({
            "name": "No Employee Mobile User",
            "login": "profile_api_noemp@test.com",
            "password": "profile_api_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })

        # Internal user WITHOUT the mobile group -- must be rejected at login.
        cls.user_not_mobile = Users.create({
            "name": "Non Mobile User",
            "login": "profile_api_nonmobile@test.com",
            "password": "profile_api_pw_1234",
            "group_ids": [(4, cls.env.ref("base.group_user").id)],
        })

    def _login(self, login, password):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": login, "password": password},
            headers={"Content-Type": "application/json"},
        )
        return resp.json()

    def _token_for(self, login, password):
        body = self._login(login, password)
        self.assertTrue(body["success"], "login unexpectedly failed: %s" % body)
        return body["data"]["token"]

    def _get(self, path, token):
        resp = self.url_open(path, headers={"Authorization": "Bearer %s" % token})
        return resp.status_code, resp.json() if resp.headers.get(
            "Content-Type", "").startswith("application/json") else None

    def test_mobile_user_can_fetch_own_profile(self):
        """A mobile user with a linked employee gets a successful profile."""
        token = self._token_for(
            "profile_api_user@test.com", "profile_api_pw_1234")
        status, body = self._get("/api/mobile/v1/profile", token)
        self.assertEqual(status, 200)
        self.assertTrue(body["success"])
        self.assertEqual(body["data"]["id"], self.employee.id)
        self.assertEqual(body["data"]["name"], "Mobile Employee")

    def test_profile_includes_content_flags(self):
        """Profile carries the 3 Other Data booleans, always present + bool."""
        token = self._token_for(
            "profile_api_user@test.com", "profile_api_pw_1234")
        status, body = self._get("/api/mobile/v1/profile", token)
        self.assertEqual(status, 200)
        data = body["data"]
        for key in ("show_privacy_policy", "show_terms_conditions", "show_faq"):
            self.assertIn(key, data)
            self.assertIsInstance(data[key], bool)

    def test_profile_content_flags_reflect_published_state(self):
        """Flags are True once content is published / an active FAQ exists."""
        self.env["mobile.privacy.policy"].sudo().get_privacy_policy().write(
            {"body": "<p>x</p>", "is_published": True})
        self.env["mobile.terms.condition"].sudo().get_terms().write(
            {"body": "<p>y</p>", "is_published": True})
        self.env["mobile.faq"].sudo().create(
            {"heading": "Q", "sub_heading": "a"})
        self.env.flush_all()
        token = self._token_for(
            "profile_api_user@test.com", "profile_api_pw_1234")
        status, body = self._get("/api/mobile/v1/profile", token)
        data = body["data"]
        self.assertTrue(data["show_privacy_policy"])
        self.assertTrue(data["show_terms_conditions"])
        self.assertTrue(data["show_faq"])

    def test_non_mobile_user_is_rejected(self):
        """A user without group_mobile_user cannot even obtain a token."""
        body = self._login(
            "profile_api_nonmobile@test.com", "profile_api_pw_1234")
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "mobile_access_denied")
        self.assertNotIn("error", body)  # standard envelope, no nested key

    def test_user_without_employee_gets_safe_error(self):
        """A live token whose employee was unlinked gets a clean 404, not a crash."""
        token = self._token_for("profile_api_user@test.com", "profile_api_pw_1234")
        self.employee.write({"user_id": False})
        self.env.flush_all()
        self.addCleanup(self.employee.write, {"user_id": self.user.id})
        status, body = self._get("/api/mobile/v1/profile", token)
        self.assertEqual(status, 404)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "employee_not_linked")
        # Must be our clean envelope, never a raw Odoo/werkzeug error page.
        self.assertIn("message", body)
        self.assertNotIn("traceback", json.dumps(body).lower())

    def test_profile_response_includes_required_fields(self):
        """The profile payload has every field the mobile screen needs."""
        token = self._token_for(
            "profile_api_user@test.com", "profile_api_pw_1234")
        status, body = self._get("/api/mobile/v1/profile", token)
        self.assertEqual(status, 200)
        data = body["data"]
        for field in (
            "id", "name", "job_title", "email", "phone", "mobile",
            "department", "company", "work_location", "avatar_url",
            "initials", "report_to", "team", "header", "work", "personal",
            "docs",
        ):
            self.assertIn(field, data, "missing field: %s" % field)
        self.assertIn("avatar_url", data["header"])
        self.assertIn("bank", data["work"])
        self.assertIn("personal_email", data["personal"])
        self.assertIn("employee_documents", data["docs"])
        self.assertIn("certificates", data["docs"])

    def test_manager_is_returned_when_available(self):
        """report_to reflects the employee's actual parent_id."""
        token = self._token_for(
            "profile_api_user@test.com", "profile_api_pw_1234")
        status, body = self._get("/api/mobile/v1/profile", token)
        self.assertEqual(status, 200)
        report_to = body["data"]["report_to"]
        self.assertIsNotNone(report_to)
        self.assertEqual(report_to["id"], self.manager_emp.id)
        self.assertEqual(report_to["name"], "Test Manager")
        self.assertEqual(report_to["email"], "manager@test.com")
        self.assertEqual(body["data"]["work"]["manager"]["email"], "manager@test.com")

    def test_manager_is_none_when_not_available(self):
        """report_to is null (not a crash) when the employee has no manager."""
        Users = self.env["res.users"].sudo()
        Employee = self.env["hr.employee"].sudo()
        mobile_group = self.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = self.env.ref("base.group_user")
        company = self.env.ref("base.main_company")
        user = Users.create({
            "name": "No Manager User",
            "login": "profile_api_nomanager@test.com",
            "password": "profile_api_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        Employee.create({
            "name": "No Manager User", "company_id": company.id,
            "user_id": user.id,
        })
        token = self._token_for(
            "profile_api_nomanager@test.com", "profile_api_pw_1234")
        status, body = self._get("/api/mobile/v1/profile", token)
        self.assertEqual(status, 200)
        self.assertIsNone(body["data"]["report_to"])
        self.assertEqual(body["data"]["team"], [])

    def test_team_list_does_not_expose_unrelated_employees(self):
        """Team only contains colleagues sharing the same manager -- never
        the full company directory."""
        token = self._token_for(
            "profile_api_user@test.com", "profile_api_pw_1234")
        status, body = self._get("/api/mobile/v1/profile", token)
        self.assertEqual(status, 200)
        team_ids = {member["id"] for member in body["data"]["team"]}
        self.assertIn(self.peer_emp.id, team_ids)
        self.assertNotIn(self.unrelated_emp.id, team_ids)
        self.assertNotIn(self.employee.id, team_ids)  # never includes self

    def test_avatar_endpoint_respects_visibility_rules(self):
        """Own/manager/team avatars are reachable; unrelated ones are denied."""
        token = self._token_for(
            "profile_api_user@test.com", "profile_api_pw_1234")

        resp = self.url_open(
            "/api/mobile/v1/profile/avatar",
            headers={"Authorization": "Bearer %s" % token})
        self.assertEqual(resp.status_code, 200)

        status, _ = self._get(
            "/api/mobile/v1/employees/%s/avatar" % self.manager_emp.id, token)
        self.assertEqual(status, 200)

        status, _ = self._get(
            "/api/mobile/v1/employees/%s/avatar" % self.peer_emp.id, token)
        self.assertEqual(status, 200)

        status, body = self._get(
            "/api/mobile/v1/employees/%s/avatar" % self.unrelated_emp.id, token)
        self.assertEqual(status, 403)
        self.assertEqual(body["code"], "employee_not_visible")

    def test_api_works_without_hr_officer_rights(self):
        """The flow works for a plain mobile user without hr.group_hr_user (no sudo reliance)."""
        self.assertFalse(
            self.user.has_group("hr.group_hr_user"),
            "test setup invariant broken: user must not be an HR Officer",
        )
        token = self._token_for(
            "profile_api_user@test.com", "profile_api_pw_1234")
        status, body = self._get("/api/mobile/v1/profile", token)
        self.assertEqual(status, 200)
        self.assertTrue(body["success"])

    def test_missing_optional_fields_do_not_crash(self):
        """An employee with no job_title/department/email/phone/work
        location still returns 200 with those fields set to null."""
        Users = self.env["res.users"].sudo()
        Employee = self.env["hr.employee"].sudo()
        mobile_group = self.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = self.env.ref("base.group_user")
        company = self.env.ref("base.main_company")
        user = Users.create({
            "name": "Bare Employee",
            "login": "profile_api_bare@test.com",
            "password": "profile_api_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        Employee.create({
            "name": "Bare Employee", "company_id": company.id,
            "user_id": user.id,
        })
        token = self._token_for(
            "profile_api_bare@test.com", "profile_api_pw_1234")
        status, body = self._get("/api/mobile/v1/profile", token)
        self.assertEqual(status, 200)
        self.assertTrue(body["success"])
        self.assertIsNone(body["data"]["job_title"])
        self.assertIsNone(body["data"]["work_location"])
        self.assertIn("header", body["data"])
        self.assertIn("work", body["data"])
        self.assertIn("personal", body["data"])
        self.assertIn("docs", body["data"])
        self.assertEqual(body["data"]["team"], [])

    def test_profile_documents_use_download_descriptor_not_raw_url(self):
        attachment = self.env["ir.attachment"].sudo().create({
            "name": "Certificate.pdf",
            "res_model": "hr.employee",
            "res_id": self.employee.id,
            "type": "binary",
            "mimetype": "application/pdf",
            "datas": base64.b64encode(b"certificate bytes"),
        })
        token = self._token_for(
            "profile_api_user@test.com", "profile_api_pw_1234")
        status, body = self._get("/api/mobile/v1/profile", token)
        self.assertEqual(status, 200)
        certificates = body["data"]["docs"]["certificates"]
        cert = next(item for item in certificates if item["id"] == attachment.id)
        self.assertNotIn("url", cert)
        self.assertEqual(cert["download"]["response"], "base64")
        self.assertIn("/api/mobile/v1/profile/documents/%s/download" % attachment.id,
                      cert["download"]["endpoint"])

        status, download = self._get(cert["download"]["endpoint"], token)
        self.assertEqual(status, 200)
        self.assertEqual(download["data"]["filename"], "Certificate.pdf")
        self.assertEqual(download["data"]["content_type"], "application/pdf")
        self.assertEqual(
            base64.b64decode(download["data"]["base64"]),
            b"certificate bytes",
        )

    def test_profile_document_download_rejects_other_employee_attachment(self):
        attachment = self.env["ir.attachment"].sudo().create({
            "name": "Other.pdf",
            "res_model": "hr.employee",
            "res_id": self.unrelated_emp.id,
            "type": "binary",
            "mimetype": "application/pdf",
            "datas": base64.b64encode(b"other bytes"),
        })
        token = self._token_for(
            "profile_api_user@test.com", "profile_api_pw_1234")
        status, body = self._get(
            "/api/mobile/v1/profile/documents/%s/download" % attachment.id,
            token,
        )
        self.assertEqual(status, 404)
        self.assertEqual(body["code"], "document_not_found")

    def test_personal_contact_is_null_when_only_work_details_exist(self):
        """Work contact details must never be served as personal ones."""
        self.employee.sudo().write({
            "work_email": "work.only@test.com",
            "work_phone": "+971500000001",
            "mobile_phone": "+971500000002",
            "private_email": False,
            "private_phone": False,
        })
        token = self._token_for(
            "profile_api_user@test.com", "profile_api_pw_1234")
        status, body = self._get("/api/mobile/v1/profile", token)
        self.assertEqual(status, 200)
        personal = body["data"]["personal"]

        self.assertIsNone(
            personal["personal_email"],
            "work email leaked into personal_email (issue 009 regression)")
        self.assertIsNone(
            personal["phone"],
            "work mobile leaked into personal phone (issue 009 regression)")

        # The work values are still served -- nothing is lost to the client.
        self.assertEqual(body["data"]["email"], "work.only@test.com")
        self.assertEqual(body["data"]["work"]["email"], "work.only@test.com")
        self.assertEqual(body["data"]["work"]["phone"], "+971500000001")

    def test_private_email_is_returned_when_actually_set(self):
        """A set private email is returned via the res.users self-read path.
        ``hr.employee.private_email`` is HR-only, so the controller reads the mirrored user field."""
        self.employee.sudo().write({
            "work_email": "work.only@test.com",
            "private_email": "private.person@test.com",
        })
        token = self._token_for(
            "profile_api_user@test.com", "profile_api_pw_1234")
        status, body = self._get("/api/mobile/v1/profile", token)
        self.assertEqual(status, 200)
        self.assertEqual(
            body["data"]["personal"]["personal_email"],
            "private.person@test.com")

    def test_private_phone_is_never_the_work_mobile(self):
        """Personal phone is never the work mobile; null is acceptable.
        ``res.users.private_phone`` has ``related_sudo=False``, so non-HR users read null."""
        self.employee.sudo().write({
            "mobile_phone": "+971500000002",
            "work_phone": "+971500000001",
            "private_phone": "+971509999999",
        })
        token = self._token_for(
            "profile_api_user@test.com", "profile_api_pw_1234")
        status, body = self._get("/api/mobile/v1/profile", token)
        self.assertEqual(status, 200)
        phone = body["data"]["personal"]["phone"]
        self.assertNotEqual(phone, "+971500000002",
                            "work mobile leaked into personal phone")
        self.assertNotEqual(phone, "+971500000001",
                            "work phone leaked into personal phone")
        self.assertIn(phone, (None, "+971509999999"))

    def test_personal_tab_reads_the_authenticated_users_private_hr_data(self):
        """The connector exposes only the caller's own allow-list."""
        country = self.env.ref("base.in")
        self.employee.sudo().write({
            "private_email": "private.person@test.com",
            "private_phone": "+919876543210",
            "birthday": "1995-04-17",
            "sex": "female",
            "marital": "single",
            "place_of_birth": "Kozhikode",
            "private_street": "12 Beach Road",
            "private_city": "Kozhikode",
            "private_zip": "673001",
            "private_country_id": country.id,
            "certificate": "master",
            "study_field": "Computer Science",
        })
        token = self._token_for(
            "profile_api_user@test.com", "profile_api_pw_1234")
        status, body = self._get("/api/mobile/v1/profile", token)
        self.assertEqual(status, 200)
        personal = body["data"]["personal"]

        self.assertEqual(personal["personal_email"], "private.person@test.com")
        self.assertEqual(personal["phone"], "+919876543210")
        self.assertEqual(personal["date_of_birth"], "1995-04-17")
        self.assertEqual(personal["birth_place"], "Kozhikode")
        self.assertEqual(personal["nationality"], country.name)
        self.assertEqual(personal["field_of_study"], "Computer Science")
        self.assertIn("12 Beach Road", personal["residential_address"])
        self.assertEqual(
            personal["permanent_address"], personal["residential_address"])
        self.assertIsNotNone(personal["gender"])
        self.assertIsNotNone(personal["marital_status"])
        self.assertIsNotNone(personal["education_level"])
