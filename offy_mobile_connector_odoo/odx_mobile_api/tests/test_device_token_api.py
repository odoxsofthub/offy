from odoo import fields
from odoo.tests import HttpCase, tagged


@tagged("-at_install", "post_install")
class TestMobileDeviceTokenApi(HttpCase):
    """Tests for POST /api/mobile/v1/device-token."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        company = cls.env.ref("base.main_company")

        cls.user_a = Users.create({
            "name": "Device Token User A",
            "login": "device_token_user_a@test.com",
            "password": "device_token_pw_1234",
            "group_ids": [(4, mobile_group.id)],
        })
        cls.user_b = Users.create({
            "name": "Device Token User B",
            "login": "device_token_user_b@test.com",
            "password": "device_token_pw_1234",
            "group_ids": [(4, mobile_group.id)],
        })
        # Login refuses an employee-less account (see test_auth_employment_gate.py).
        cls.employee_a = Employee.create({
            "name": "Device Token User A",
            "company_id": company.id,
            "user_id": cls.user_a.id,
        })
        cls.employee_b = Employee.create({
            "name": "Device Token User B",
            "company_id": company.id,
            "user_id": cls.user_b.id,
        })
        cls.config = cls.env["mobile.config"].sudo().get_config()
        cls.Token = cls.env["mobile.device.token"].sudo()

    def _token_for(self, login, password):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": login, "password": password},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login unexpectedly failed: %s" % body)
        return body["data"]["token"]

    def _register(self, access_token, firebase_id, device_type=None):
        payload = {"firebase_id": firebase_id}
        if device_type is not None:
            payload["device_type"] = device_type
        resp = self.url_open(
            "/api/mobile/v1/device-token",
            json=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": "Bearer %s" % access_token,
            },
        )
        return resp.status_code, resp.json()

    def test_mobile_user_can_register_token(self):
        self.config.max_devices = 0
        token = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        status, body = self._register(token, "fcm-a-1", "android")
        self.assertEqual(status, 200)
        self.assertTrue(body["success"])
        self.assertEqual(body["data"]["firebase_id"], "fcm-a-1")
        self.assertEqual(body["data"]["device_type"], "android")

    def test_non_mobile_user_is_rejected(self):
        """Group removed after token issuance is still caught (defense in depth)."""
        self.config.max_devices = 0
        token = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        mobile_group = self.env.ref("odx_mobile_connector.group_mobile_user")
        self.user_a.sudo().write({"group_ids": [(3, mobile_group.id)]})
        status, body = self._register(token, "fcm-a-2", "android")
        self.assertEqual(status, 403)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "mobile_access_denied")

    def test_missing_firebase_id_is_rejected(self):
        self.config.max_devices = 0
        token = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        status, body = self._register(token, "   ")
        self.assertEqual(status, 400)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "firebase_id_required")

    def test_same_user_same_token_updates_existing_line(self):
        self.config.max_devices = 0
        token = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        self._register(token, "fcm-a-3", "android")
        row = self.Token.search([("firebase_id", "=", "fcm-a-3")])
        old_date = fields.Datetime.to_datetime("2026-01-01 00:00:00")
        row.write({"registered_at": old_date, "updated_at": old_date})
        self._register(token, "fcm-a-3", "ios")
        rows = self.Token.search([("firebase_id", "=", "fcm-a-3")])
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows.device_type, "ios")
        self.assertEqual(rows.registered_at, old_date)
        self.assertNotEqual(rows.updated_at, old_date)

    def test_token_transferred_from_another_user(self):
        self.config.max_devices = 0
        token_a = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        token_b = self._token_for("device_token_user_b@test.com", "device_token_pw_1234")
        self._register(token_a, "fcm-shared", "android")
        self._register(token_b, "fcm-shared", "ios")
        rows = self.Token.search([("firebase_id", "=", "fcm-shared")])
        self.assertEqual(len(rows), 1, "old owner's row must be deactivated, not duplicated")
        self.assertEqual(rows.user_id, self.user_b)

    def test_max_devices_zero_allows_many_lines(self):
        self.config.max_devices = 0
        token = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        self._register(token, "fcm-many-1", "android")
        self._register(token, "fcm-many-2", "android")
        self._register(token, "fcm-many-3", "android")
        rows = self.Token.search([("session_id.user_id", "=", self.user_a.id)])
        self.assertEqual(len(rows), 3)

    def test_max_devices_one_keeps_only_newest(self):
        self.config.max_devices = 1
        token = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        self._register(token, "fcm-one-1", "android")
        self._register(token, "fcm-one-2", "android")
        rows = self.Token.search([("session_id.user_id", "=", self.user_a.id)])
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows.firebase_id, "fcm-one-2")

    def test_max_devices_two_keeps_only_newest_two(self):
        self.config.max_devices = 2
        token = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        self._register(token, "fcm-two-1", "android")
        self._register(token, "fcm-two-2", "android")
        self._register(token, "fcm-two-3", "android")
        rows = self.Token.search([("session_id.user_id", "=", self.user_a.id)])
        self.assertEqual(len(rows), 2)
        self.assertEqual(set(rows.mapped("firebase_id")), {"fcm-two-2", "fcm-two-3"})

    def test_remove_deactivates_token_line(self):
        self.config.max_devices = 0
        token = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        self._register(token, "fcm-remove-1", "android")
        row = self.Token.search([("firebase_id", "=", "fcm-remove-1")])
        row.action_remove()
        self.assertFalse(row.active)
        self.assertFalse(self.Token.search([("firebase_id", "=", "fcm-remove-1")]))

    def _logout(self, access_token, firebase_id=None):
        payload = {}
        if firebase_id is not None:
            payload["firebase_id"] = firebase_id
        resp = self.url_open(
            "/api/mobile/v1/auth/logout",
            json=payload,
            # url_open() sends GET unless the body is truthy, so an empty payload would hit 405.
            method="POST",
            headers={
                "Content-Type": "application/json",
                "Authorization": "Bearer %s" % access_token,
            },
        )
        return resp.status_code, resp.json()

    def _active_ids(self, user):
        return self.Token.search([
            ("session_id.user_id", "=", user.id), ("active", "=", True),
        ]).mapped("firebase_id")

    def test_logout_with_firebase_id_deactivates_that_token(self):
        """Logout with a firebase id deactivates that device token so it stops receiving pushes."""
        self.config.max_devices = 0
        access = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        self._register(access, "fcm-logout-a")
        self.assertIn("fcm-logout-a", self._active_ids(self.user_a))

        status, body = self._logout(access, "fcm-logout-a")
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"])
        self.assertEqual(body["data"]["push_tokens_cleared"], 1)
        self.assertNotIn("fcm-logout-a", self._active_ids(self.user_a))

    def test_logout_stamps_the_reason(self):
        self.config.max_devices = 0
        access = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        self._register(access, "fcm-reason")
        self._logout(access, "fcm-reason")
        # active_test=False: the row was just deactivated, so a default search would miss it.
        row = self.Token.with_context(active_test=False).search(
            [("firebase_id", "=", "fcm-reason")], limit=1)
        self.assertEqual(row.removed_reason, "logout")
        self.assertTrue(row.removed_at)

    def test_logout_leaves_the_users_other_devices_alone(self):
        """Signing out of the phone must not silence the tablet."""
        self.config.max_devices = 0
        access = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        self._register(access, "fcm-phone")
        self._register(access, "fcm-tablet")

        self._logout(access, "fcm-phone")
        remaining = self._active_ids(self.user_a)
        self.assertNotIn("fcm-phone", remaining)
        self.assertIn("fcm-tablet", remaining)

    def test_logout_never_touches_another_users_token(self):
        """A firebase_id from the client is scoped to the caller's own rows."""
        self.config.max_devices = 0
        access_b = self._token_for("device_token_user_b@test.com", "device_token_pw_1234")
        self._register(access_b, "fcm-belongs-to-b")

        access_a = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        status, body = self._logout(access_a, "fcm-belongs-to-b")
        self.assertEqual(status, 200, body)
        self.assertEqual(body["data"]["push_tokens_cleared"], 0)
        self.assertIn("fcm-belongs-to-b", self._active_ids(self.user_b))

    def test_logout_without_firebase_id_clears_when_single_device(self):
        """Without a firebase id, logout clears tokens when max_devices == 1 (the token must be this device's)."""
        self.config.max_devices = 1
        access = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        self._register(access, "fcm-implicit")
        status, body = self._logout(access)
        self.assertEqual(status, 200, body)
        self.assertEqual(body["data"]["push_tokens_cleared"], 1)
        self.assertNotIn("fcm-implicit", self._active_ids(self.user_a))

    def test_logout_without_firebase_id_does_not_guess_on_multi_device(self):
        """Above one device it must not silence a phone that is still signed in."""
        self.config.max_devices = 0  # unlimited
        access = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        self._register(access, "fcm-keep-1")
        self._register(access, "fcm-keep-2")
        status, body = self._logout(access)
        self.assertEqual(status, 200, body)
        self.assertEqual(body["data"]["push_tokens_cleared"], 0)
        self.assertEqual(
            sorted(self._active_ids(self.user_a)), ["fcm-keep-1", "fcm-keep-2"])

    def test_logout_is_still_successful_with_no_token_registered(self):
        self.config.max_devices = 1
        access = self._token_for("device_token_user_a@test.com", "device_token_pw_1234")
        status, body = self._logout(access, "never-registered")
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"])
        self.assertEqual(body["data"]["push_tokens_cleared"], 0)
