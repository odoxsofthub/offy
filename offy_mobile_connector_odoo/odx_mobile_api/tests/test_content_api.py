from odoo.tests import HttpCase, tagged


@tagged("-at_install", "post_install")
class TestMobileContentApi(HttpCase):
    """GET /privacy-policy, /terms-conditions, /faqs, /other-data.
    Authenticates through the real /auth/login endpoint like a mobile client."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.password = "content_api_pw_1234"
        cls.user = Users.create({
            "name": "Content Mobile User",
            "login": "content_api_user@test.com",
            "password": cls.password,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        # Login refuses an employee-less account (see test_auth_employment_gate.py).
        cls.employee = Employee.create({
            "name": "Content Mobile User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })
        cls.user_not_mobile = Users.create({
            "name": "Non Mobile User",
            "login": "content_api_nonmobile@test.com",
            "password": cls.password,
            "group_ids": [(4, internal_group.id)],
        })

        # Publish the shipped singleton defaults with real bodies.
        cls.privacy = cls.env.ref(
            "odx_mobile_connector.mobile_privacy_policy_default")
        cls.privacy.write({
            "body": "<p>Our <strong>privacy</strong> policy.</p>",
            "is_published": True,
        })
        cls.terms = cls.env.ref(
            "odx_mobile_connector.mobile_terms_condition_default")
        cls.terms.write({
            "body": "<p>These are the <em>terms</em>.</p>",
            "is_published": True,
        })

        Faq = cls.env["mobile.faq"].sudo()
        cls.faq_second = Faq.create({
            "heading": "Second question", "sub_heading": "second answer",
            "sequence": 20})
        cls.faq_first = Faq.create({
            "heading": "First question", "sub_heading": "first answer",
            "sequence": 10})
        cls.faq_archived = Faq.create({
            "heading": "Archived question", "sub_heading": "hidden",
            "sequence": 5, "active": False})

    def _token(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": "content_api_user@test.com", "password": self.password},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"]

    def _get(self, path, token=None):
        headers = {"Authorization": "Bearer %s" % token} if token else {}
        resp = self.url_open(path, headers=headers)
        return resp.status_code, resp.json()

    def test_missing_token_rejected(self):
        status, body = self._get("/api/mobile/v1/privacy-policy")
        self.assertEqual(status, 401)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "missing_access_token")

    def test_non_mobile_user_rejected_at_login(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": "content_api_nonmobile@test.com",
                  "password": self.password},
            headers={"Content-Type": "application/json"},
        )
        self.assertFalse(resp.json()["success"])

    def test_privacy_published(self):
        token = self._token()
        status, body = self._get("/api/mobile/v1/privacy-policy", token)
        self.assertEqual(status, 200)
        self.assertTrue(body["success"])
        policy = body["data"]["privacy_policy"]
        self.assertIsNotNone(policy)
        self.assertIn("<strong>privacy</strong>", policy["body"])
        self.assertTrue(policy["is_published"])

    def test_privacy_unpublished_returns_null(self):
        self.privacy.write({"is_published": False})
        self.env.flush_all()
        token = self._token()
        status, body = self._get("/api/mobile/v1/privacy-policy", token)
        self.assertEqual(status, 200)
        self.assertTrue(body["success"])
        self.assertIsNone(body["data"]["privacy_policy"])
        # restore for isolation
        self.privacy.write({"is_published": True})
        self.env.flush_all()

    def test_terms_published(self):
        token = self._token()
        status, body = self._get("/api/mobile/v1/terms-conditions", token)
        self.assertEqual(status, 200)
        terms = body["data"]["terms_conditions"]
        self.assertIsNotNone(terms)
        self.assertIn("<em>terms</em>", terms["body"])

    def test_faqs_active_only_and_ordered(self):
        token = self._token()
        status, body = self._get("/api/mobile/v1/faqs", token)
        self.assertEqual(status, 200)
        faqs = body["data"]["faqs"]
        titles = [f["title"] for f in faqs]
        self.assertEqual(titles, ["First question", "Second question"])
        self.assertNotIn("Archived question", titles)
        self.assertEqual(faqs[0]["description"], "first answer")

    def test_other_data_aggregate(self):
        token = self._token()
        status, body = self._get("/api/mobile/v1/other-data", token)
        self.assertEqual(status, 200)
        data = body["data"]
        self.assertIn("privacy_policy", data)
        self.assertIn("terms_conditions", data)
        self.assertIn("faqs", data)
        self.assertEqual(len(data["faqs"]), 2)
