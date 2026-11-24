from datetime import timedelta

from odoo import fields
from odoo.tests import HttpCase, tagged

LOGIN = "pw_logout_user@test.com"
OLD_PASSWORD = "pw_logout_old_1234"
NEW_PASSWORD = "pw_logout_new_5678"
OTHER_LOGIN = "pw_logout_other@test.com"


@tagged("post_install", "-at_install")
class TestPasswordChangeLogsOutMobile(HttpCase):
    """Changing the password must evict the phone, which core does not do for API keys or refresh tokens.
    The refresh token matters most: it rotates for 30 days, so access token expiry alone is not enough.
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        groups = [(4, mobile_group.id), (4, internal_group.id)]
        company = cls.env.ref("base.main_company")

        cls.user = Users.create({
            "name": "PW Logout User", "login": LOGIN,
            "password": OLD_PASSWORD, "group_ids": groups,
        })
        Employee.create({"name": "PW Logout User", "company_id": company.id,
                         "user_id": cls.user.id})

        # A second mobile user, to prove the blast radius is one account.
        cls.other_user = Users.create({
            "name": "PW Logout Other", "login": OTHER_LOGIN,
            "password": OLD_PASSWORD, "group_ids": groups,
        })
        Employee.create({"name": "PW Logout Other", "company_id": company.id,
                         "user_id": cls.other_user.id})

    # Helpers
    def _login(self, login=LOGIN, password=OLD_PASSWORD):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": login, "password": password},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"], body["data"]["refreshToken"]

    def _get(self, path, token):
        resp = self.url_open(
            path, headers={"Authorization": "Bearer %s" % token})
        return resp.status_code, resp.json()

    def _refresh(self, refresh_token):
        resp = self.url_open(
            "/api/mobile/v1/auth/refresh",
            json={"refreshToken": refresh_token},
            headers={"Content-Type": "application/json"},
        )
        return resp.status_code, resp.json()

    def _change_password(self, user=None, password=NEW_PASSWORD):
        (user or self.user).sudo()._change_password(password)
        self.env.flush_all()

    # The access token
    def test_access_token_stops_working(self):
        token, _rt = self._login()
        status, _ = self._get("/api/mobile/v1/home", token)
        self.assertEqual(status, 200, "sanity: the session works to begin with")

        self._change_password()

        status, body = self._get("/api/mobile/v1/home", token)
        self.assertEqual(status, 401, body)
        self.assertEqual(body["code"], "invalid_access_token")

    def test_every_endpoint_is_closed_not_just_one(self):
        token, _rt = self._login()
        self._change_password()
        for path in ("/api/mobile/v1/home", "/api/mobile/v1/profile",
                     "/api/mobile/v1/expense/summary",
                     "/api/mobile/v1/notifications"):
            status, body = self._get(path, token)
            self.assertEqual(status, 401, "%s stayed open: %s" % (path, body))

    # The refresh token
    def test_refresh_token_cannot_mint_a_new_session(self):
        """The refresh token must not mint a new session after a password change."""
        _token, refresh_token = self._login()
        self._change_password()

        status, body = self._refresh(refresh_token)
        self.assertEqual(status, 401, body)
        self.assertEqual(body["code"], "invalid_refresh_token")
        self.assertFalse(body.get("data", {}).get("token"),
                         "a new access token was handed out")

    # Push
    def test_push_tokens_are_deactivated_with_their_own_reason(self):
        """Push tokens are deactivated too, tagged `password_changed` rather than `logout`."""
        token, _rt = self._login()
        resp = self.url_open(
            "/api/mobile/v1/device-token",
            json={"firebase_id": "pw-logout-device", "device_type": "android"},
            headers={"Authorization": "Bearer %s" % token,
                     "Content-Type": "application/json"},
        )
        self.assertTrue(resp.json()["success"], resp.json())

        self._change_password()

        device = self.env["mobile.device.token"].sudo().with_context(
            active_test=False).search([("user_id", "=", self.user.id)])
        self.assertTrue(device, "the fixture never registered a push token")
        self.assertFalse(any(device.mapped("active")))
        self.assertEqual(set(device.mapped("removed_reason")),
                         {"password_changed"})

    # Blast radius
    def test_only_that_users_sessions_are_revoked(self):
        victim_token, _ = self._login(OTHER_LOGIN, OLD_PASSWORD)
        self._change_password()
        status, body = self._get("/api/mobile/v1/home", victim_token)
        self.assertEqual(status, 200,
                         "another user's phone was signed out too: %s" % body)

    def test_non_mobile_api_keys_survive(self):
        """Integration API keys are not mobile sessions and must survive a password change."""
        key = self.env["res.users.apikeys"].with_user(self.user)._generate(
            "rpc", "integration key",
            fields.Datetime.now() + timedelta(days=30))
        self.assertTrue(key)
        self._change_password()
        self.assertEqual(
            self.env["res.users.apikeys"].sudo().search_count([
                ("user_id", "=", self.user.id), ("scope", "=", "rpc")]),
            1, "a non-mobile API key was revoked")

    # The hook itself
    def test_a_plain_write_also_revokes(self):
        """`password` is an inverse field, so every change path funnels through `_set_password`, including a bare write()."""
        token, refresh_token = self._login()
        self.user.sudo().write({"password": NEW_PASSWORD})
        self.env.flush_all()

        status, _ = self._get("/api/mobile/v1/home", token)
        self.assertEqual(status, 401)
        status, _ = self._refresh(refresh_token)
        self.assertEqual(status, 401)

    def test_the_new_password_still_signs_in(self):
        """Fail-closed must not mean locked out."""
        self._login()
        self._change_password()
        token, _rt = self._login(LOGIN, NEW_PASSWORD)
        status, _ = self._get("/api/mobile/v1/home", token)
        self.assertEqual(status, 200)
