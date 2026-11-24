from datetime import timedelta
from unittest.mock import patch

from odoo.fields import Datetime
from odoo.tests import TransactionCase, tagged

from .push_common import encode_service_account, make_service_account


@tagged("post_install", "-at_install")
class TestMobilePushService(TransactionCase):
    """The generic Firebase delivery service: token scoping, safe errors,
    and permanent/temporary failure handling."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.service = cls.env["mobile.push.service"]
        cls.config = cls.env["mobile.config"].sudo().get_config()
        cls.Token = cls.env["mobile.device.token"].sudo()

        internal = cls.env.ref("base.group_user")
        mobile = cls.env.ref("odx_mobile_connector.group_mobile_user")

        def _make_user(login):
            return cls.env["res.users"].create({
                "name": login,
                "login": login,
                "group_ids": [(4, internal.id), (4, mobile.id)],
            })

        cls.user_a = _make_user("push_user_a@test.com")
        cls.user_b = _make_user("push_user_b@test.com")
        cls.user_c = _make_user("push_user_c@test.com")  # no tokens

    def _enable_push(self):
        """Enable push with a structurally valid offline service account (network is mocked per test)."""
        self.config.write({
            "firebase_service_account_file": encode_service_account(
                make_service_account()),
            "push_notifications_enabled": True,
        })

    def test_active_tokens_are_scoped_to_the_target_user(self):
        self.Token.register_token(self.user_a, "fcm-a", "android")
        self.Token.register_token(self.user_b, "fcm-b", "ios")
        tokens_a = self.service._active_tokens_for_user(self.user_a)
        self.assertTrue(tokens_a)
        self.assertEqual(tokens_a.mapped("user_id"), self.user_a)
        self.assertNotIn(
            "fcm-b", tokens_a.mapped("firebase_id"),
            "another user's token must never be resolved",
        )

    def test_deactivated_tokens_are_ignored(self):
        self.Token.register_token(self.user_a, "fcm-dead", "android")
        token = self.Token.search([("firebase_id", "=", "fcm-dead")])
        token.action_remove()  # soft delete
        self.assertFalse(self.service._active_tokens_for_user(self.user_a))

    def test_send_when_disabled_returns_safe_error(self):
        # push_notifications_enabled is the only gate; disable it explicitly since data defaults it to True.
        self.config.write({"push_notifications_enabled": False})
        result = self.service.send_to_user(self.user_a, "Hi", "Body")
        self.assertFalse(result["success"])
        self.assertEqual(result["error"]["code"], "firebase_disabled")

    def test_send_with_incomplete_config_returns_safe_error(self):
        # Enabled with a file present but missing keys: delivery bails out before any network use.
        incomplete = make_service_account(drop=["private_key"])
        self.config.write({
            "firebase_service_account_file": encode_service_account(incomplete),
            "push_notifications_enabled": True,
        })
        self.Token.register_token(self.user_a, "fcm-a", "android")
        result = self.service.send_to_user(self.user_a, "Hi", "Body")
        self.assertFalse(result["success"])
        self.assertEqual(result["error"]["code"], "firebase_config_missing")
        # The response must never carry credential material.
        self.assertNotIn("private_key", str(result))

    def test_send_to_user_without_tokens_is_a_skip_success(self):
        self._enable_push()
        result = self.service.send_to_user(self.user_c, "Hi", "Body")
        self.assertTrue(result["success"])
        self.assertEqual(result["data"]["sent"], 0)
        self.assertEqual(result["data"]["skipped"], 1)

    def test_send_reaches_every_active_token(self):
        self._enable_push()
        self.config.write({"max_devices": 0})  # before registering, so neither token is evicted
        self.Token.register_token(self.user_a, "fcm-multi-1", "android")
        self.Token.register_token(self.user_a, "fcm-multi-2", "ios")

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token", return_value="fake-token"), \
             patch.object(Service, "_post_message", return_value=(True, None, None, 200)) as post:
            result = self.service.send_to_user(self.user_a, "Hi", "Body")

        self.assertTrue(result["success"])
        self.assertEqual(result["data"]["sent"], 2)
        self.assertEqual(post.call_count, 2, "every active token must get its own send attempt")

    def test_one_token_failure_does_not_stop_others(self):
        self._enable_push()
        self.config.write({"max_devices": 0})
        self.Token.register_token(self.user_a, "fcm-fail", "android")
        self.Token.register_token(self.user_a, "fcm-ok", "android")

        def fake_post(endpoint, access_token, device_token, title, body, data):
            if device_token == "fcm-fail":
                return False, "UNAVAILABLE", "temporarily down", 503
            return True, None, None, 200

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token", return_value="fake-token"), \
             patch.object(Service, "_post_message", side_effect=fake_post):
            result = self.service.send_to_user(self.user_a, "Hi", "Body")

        self.assertEqual(result["data"]["sent"], 1)
        self.assertEqual(result["data"]["failed"], 1)

    def test_classify_failure_permanent_codes(self):
        self.assertEqual(self.service._classify_failure(404, None), "permanent")
        self.assertEqual(self.service._classify_failure(500, "UNREGISTERED"), "permanent")
        self.assertEqual(self.service._classify_failure(403, "NOT_FOUND"), "permanent")
        self.assertEqual(self.service._classify_failure(400, "INVALID_ARGUMENT"), "permanent")
        self.assertEqual(self.service._classify_failure(403, "SENDER_ID_MISMATCH"), "permanent")

    def test_classify_failure_temporary_codes(self):
        self.assertEqual(self.service._classify_failure(503, "UNAVAILABLE"), "temporary")
        self.assertEqual(self.service._classify_failure(500, "INTERNAL"), "temporary")
        self.assertEqual(self.service._classify_failure(429, "QUOTA_EXCEEDED"), "temporary")
        self.assertEqual(self.service._classify_failure(None, "timeout"), "temporary")
        self.assertEqual(self.service._classify_failure(None, "network_error"), "temporary")
        # Unknown/empty status defaults to temporary: never destroy a token on an unrecognized error.
        self.assertEqual(self.service._classify_failure(500, None), "temporary")

    def test_permanent_failure_deactivates_token_immediately(self):
        self._enable_push()
        self.config.write({"max_devices": 0})
        self.Token.register_token(self.user_a, "fcm-permanent", "android")
        token = self.Token.search([("firebase_id", "=", "fcm-permanent")])

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token", return_value="fake-token"), \
             patch.object(Service, "_post_message",
                          return_value=(False, "UNREGISTERED", "gone", 404)):
            self.service.send_to_user(self.user_a, "Hi", "Body")

        self.assertFalse(token.active)
        self.assertEqual(token.removed_reason, "permanent_firebase_failure")
        self.assertTrue(token.removed_at)
        self.assertEqual(token.last_failure_code, "UNREGISTERED")

    def test_temporary_failure_increments_without_deactivating(self):
        self._enable_push()
        self.config.write({"max_devices": 0, "firebase_token_failure_limit": 5})
        self.Token.register_token(self.user_a, "fcm-temp", "android")
        token = self.Token.search([("firebase_id", "=", "fcm-temp")])

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token", return_value="fake-token"), \
             patch.object(Service, "_post_message",
                          return_value=(False, "UNAVAILABLE", "down", 503)):
            self.service.send_to_user(self.user_a, "Hi", "Body")

        self.assertTrue(token.active)
        self.assertEqual(token.failure_count, 1)
        self.assertTrue(token.last_failure_at)

    def test_successful_send_resets_failure_count(self):
        self._enable_push()
        self.config.write({"max_devices": 0})
        self.Token.register_token(self.user_a, "fcm-recover", "android")
        token = self.Token.search([("firebase_id", "=", "fcm-recover")])
        token.write({"failure_count": 3, "last_failure_code": "UNAVAILABLE"})

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token", return_value="fake-token"), \
             patch.object(Service, "_post_message", return_value=(True, None, None, 200)):
            self.service.send_to_user(self.user_a, "Hi", "Body")

        self.assertEqual(token.failure_count, 0)
        self.assertFalse(token.last_failure_code)
        self.assertTrue(token.last_success_at)

    def test_repeated_temporary_failures_deactivate_at_threshold(self):
        self._enable_push()
        self.config.write({"max_devices": 0, "firebase_token_failure_limit": 2})
        self.Token.register_token(self.user_a, "fcm-threshold", "android")
        token = self.Token.search([("firebase_id", "=", "fcm-threshold")])

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token", return_value="fake-token"), \
             patch.object(Service, "_post_message",
                          return_value=(False, "UNAVAILABLE", "down", 503)):
            self.service.send_to_user(self.user_a, "Hi", "Body")  # failure_count -> 1
            self.assertTrue(token.active)
            self.service.send_to_user(self.user_a, "Hi", "Body")  # failure_count -> 2 == limit

        self.assertFalse(token.active)
        self.assertEqual(token.removed_reason, "temporary_failure_threshold")

    def test_auto_deactivate_disabled_keeps_token_active_past_limit(self):
        self._enable_push()
        self.config.write({
            "max_devices": 0,
            "firebase_token_failure_limit": 1,
            "firebase_token_auto_deactivate_failed": False,
        })
        self.Token.register_token(self.user_a, "fcm-no-auto", "android")
        token = self.Token.search([("firebase_id", "=", "fcm-no-auto")])

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token", return_value="fake-token"), \
             patch.object(Service, "_post_message",
                          return_value=(False, "UNAVAILABLE", "down", 503)):
            self.service.send_to_user(self.user_a, "Hi", "Body")

        self.assertTrue(token.active, "auto-deactivate is off, so the token must stay active")
        self.assertEqual(token.failure_count, 1)

    def test_send_once_skips_when_already_sent(self):
        self._enable_push()
        self.Token.register_token(self.user_a, "fcm-once", "android")
        Log = self.env["mobile.notification.log"].sudo()
        Log.create({
            "user_id": self.user_a.id,
            "notification_type": "payslip_available",
            "res_model": "hr.payslip",
            "res_id": 1,
            "status": "sent",
        })

        Service = type(self.service)
        with patch.object(Service, "send_to_user") as send_mock:
            result = self.service.send_once_to_user(
                self.user_a, "payslip_available", "hr.payslip", 1, "Hi", "Body")

        send_mock.assert_not_called()
        self.assertTrue(result["success"])
        self.assertTrue(result["data"]["skipped"])
        self.assertEqual(result["data"]["reason"], "already_sent")

    def test_send_once_logs_sent_status_on_success(self):
        self._enable_push()
        self.Token.register_token(self.user_a, "fcm-log-sent", "android")
        self.config.write({"max_devices": 0})

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token", return_value="fake-token"), \
             patch.object(Service, "_post_message", return_value=(True, None, None, 200)):
            self.service.send_once_to_user(
                self.user_a, "payslip_available", "hr.payslip", 2, "Hi", "Body")

        log = self.env["mobile.notification.log"].sudo().search([
            ("user_id", "=", self.user_a.id),
            ("notification_type", "=", "payslip_available"),
            ("res_model", "=", "hr.payslip"),
            ("res_id", "=", 2),
        ])
        self.assertEqual(len(log), 1)
        self.assertEqual(log.status, "sent")

    def test_send_once_does_not_block_retry_after_skip(self):
        """A skipped attempt (e.g. push disabled) must not permanently
        prevent a later real send once the condition is fixed."""
        self.config.write({"push_notifications_enabled": False})
        result1 = self.service.send_once_to_user(
            self.user_a, "payslip_available", "hr.payslip", 3, "Hi", "Body")
        self.assertEqual(result1["error"]["code"], "firebase_disabled")

        self._enable_push()
        self.Token.register_token(self.user_a, "fcm-retry", "android")
        self.config.write({"max_devices": 0})

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token", return_value="fake-token"), \
             patch.object(Service, "_post_message", return_value=(True, None, None, 200)):
            result2 = self.service.send_once_to_user(
                self.user_a, "payslip_available", "hr.payslip", 3, "Hi", "Body")

        self.assertTrue(result2["success"])
        self.assertEqual(result2["data"]["sent"], 1)

    def test_cron_cleanup_deactivates_stale_over_threshold_tokens(self):
        self.config.write({
            "firebase_token_failure_limit": 3,
            "firebase_token_failure_window_hours": 1,
            "firebase_token_auto_deactivate_failed": True,
        })
        self.Token.register_token(self.user_a, "fcm-stale", "android")
        token = self.Token.search([("firebase_id", "=", "fcm-stale")])
        # Simulate an old failure streak over the lowered limit that was never cleaned up live.
        token.write({
            "failure_count": 3,
            "last_failure_at": Datetime.now() - timedelta(hours=2),
        })

        self.env["mobile.device.token"]._cron_cleanup_stale_tokens()

        self.assertFalse(token.active)
        self.assertEqual(token.removed_reason, "temporary_failure_threshold")

    def test_cron_cleanup_ignores_tokens_within_window(self):
        self.config.write({
            "firebase_token_failure_limit": 3,
            "firebase_token_failure_window_hours": 72,
            "firebase_token_auto_deactivate_failed": True,
        })
        self.Token.register_token(self.user_a, "fcm-recent", "android")
        token = self.Token.search([("firebase_id", "=", "fcm-recent")])
        token.write({"failure_count": 3})  # last_failure_at defaults to now

        self.env["mobile.device.token"]._cron_cleanup_stale_tokens()

        self.assertTrue(token.active, "a recent failure streak is still within its window")

    def test_cron_cleanup_noop_when_auto_deactivate_disabled(self):
        self.config.write({
            "firebase_token_failure_limit": 1,
            "firebase_token_auto_deactivate_failed": False,
        })
        self.Token.register_token(self.user_a, "fcm-manual-only", "android")
        token = self.Token.search([("firebase_id", "=", "fcm-manual-only")])
        token.write({
            "failure_count": 5,
            "last_failure_at": Datetime.now() - timedelta(hours=200),
        })

        self.env["mobile.device.token"]._cron_cleanup_stale_tokens()

        self.assertTrue(token.active)

    def test_jwt_assertion_is_built_and_signed_offline(self):
        sa = make_service_account()
        assertion = self.service._build_signed_jwt(sa)
        self.assertIsInstance(assertion, str)
        # header.claims.signature
        self.assertEqual(assertion.count("."), 2)
