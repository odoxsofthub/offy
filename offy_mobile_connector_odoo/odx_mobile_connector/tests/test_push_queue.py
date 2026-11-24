from unittest.mock import patch

from odoo.tests import TransactionCase, tagged

from ..models.mobile_notification_log import MAX_DISPATCH_ATTEMPTS
from .push_common import encode_service_account, make_service_account


@tagged("post_install", "-at_install")
class TestMobilePushQueue(TransactionCase):
    """Queued delivery: ``queue_once_to_user`` does no network I/O; ``_cron_dispatch_pending`` delivers."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.service = cls.env["mobile.push.service"]
        cls.config = cls.env["mobile.config"].sudo().get_config()
        cls.Token = cls.env["mobile.device.token"].sudo()
        cls.Log = cls.env["mobile.notification.log"].sudo()

        internal = cls.env.ref("base.group_user")
        mobile = cls.env.ref("odx_mobile_connector.group_mobile_user")
        cls.user = cls.env["res.users"].create({
            "name": "queue_user@test.com",
            "login": "queue_user@test.com",
            "group_ids": [(4, internal.id), (4, mobile.id)],
        })

    def _enable_push(self):
        self.config.write({
            "firebase_service_account_file": encode_service_account(
                make_service_account()),
            "push_notifications_enabled": True,
        })

    def _queue(self, res_id=1, notification_type="test_event"):
        return self.service.queue_once_to_user(
            self.user, notification_type, "res.partner", res_id,
            "Title", "Body", data={"k": "v"},
        )

    def _logs(self, res_id=1):
        return self.Log.search([
            ("user_id", "=", self.user.id), ("res_id", "=", res_id),
        ])

    def test_queue_creates_pending_row_without_touching_firebase(self):
        Service = type(self.service)
        with patch.object(Service, "_post_message") as post, \
             patch.object(Service, "_fetch_access_token") as auth:
            result = self._queue()

        self.assertTrue(result["success"])
        self.assertTrue(result["data"]["queued"])
        post.assert_not_called()
        auth.assert_not_called()

        log = self._logs()
        self.assertEqual(len(log), 1)
        self.assertEqual(log.status, "pending")
        self.assertEqual(log.attempt_count, 0)

    def test_queue_works_with_push_disabled(self):
        """The in-app inbox must still receive the notification."""
        self._queue()
        self.assertEqual(self._logs().status, "pending")

    def test_second_queue_while_pending_is_deduped(self):
        self._queue()
        result = self._queue()
        self.assertFalse(result["data"]["queued"])
        self.assertEqual(len(self._logs()), 1)

    def test_queue_after_sent_is_deduped(self):
        self._queue()
        self._logs().write({"status": "sent"})
        result = self._queue()
        self.assertFalse(result["data"]["queued"])
        self.assertEqual(len(self._logs()), 1)

    def test_failed_row_does_not_block_a_new_queue(self):
        """A past failure is a transient condition, not a permanent veto."""
        self._queue()
        self._logs().write({"status": "failed"})
        result = self._queue()
        self.assertTrue(result["data"]["queued"])
        self.assertEqual(len(self._logs()), 2)

    def test_queueing_triggers_the_dispatch_cron(self):
        """Delivery must not wait for the next scheduled tick."""
        Cron = type(self.env["ir.cron"])
        with patch.object(Cron, "_trigger") as trigger:
            self._queue()
        trigger.assert_called_once()

    def test_cron_is_triggered_once_per_transaction(self):
        """A bulk approval needs one wake-up, not one per notification."""
        Cron = type(self.env["ir.cron"])
        with patch.object(Cron, "_trigger") as trigger:
            for res_id in range(1, 6):
                self._queue(res_id=res_id)
        self.assertEqual(trigger.call_count, 1)

    def test_deduped_queue_does_not_trigger(self):
        self._queue()
        Cron = type(self.env["ir.cron"])
        with patch.object(Cron, "_trigger") as trigger:
            # Same key: suppressed, so there is nothing new to deliver.
            self.env.cr.precommit.data.pop("mobile_push_dispatch_triggered", None)
            self._queue()
        trigger.assert_not_called()

    def test_trigger_failure_does_not_break_queueing(self):
        """The business write must survive a broken cron trigger."""
        Cron = type(self.env["ir.cron"])
        with patch.object(Cron, "_trigger", side_effect=RuntimeError("locked")):
            result = self._queue()
        self.assertTrue(result["data"]["queued"])
        self.assertEqual(self._logs().status, "pending")

    def test_full_batch_re_triggers_to_drain_the_rest(self):
        self._enable_push()
        self.Token.register_token(self.user, "fcm-queue", "android")
        for res_id in range(1, 4):
            self._queue(res_id=res_id)

        Service = type(self.service)
        Cron = type(self.env["ir.cron"])
        with patch.object(Service, "_fetch_access_token", return_value="tok"), \
             patch.object(Service, "_post_message",
                          return_value=(True, None, None, 200)), \
             patch.object(Cron, "_trigger") as trigger:
            # batch_size below the pending count simulates a full batch.
            self.env.cr.precommit.data.pop("mobile_push_dispatch_triggered", None)
            self.service._cron_dispatch_pending(batch_size=3)

        trigger.assert_called_once()

    def test_partial_batch_does_not_re_trigger(self):
        self._enable_push()
        self.Token.register_token(self.user, "fcm-queue", "android")
        self._queue()

        Service = type(self.service)
        Cron = type(self.env["ir.cron"])
        with patch.object(Service, "_fetch_access_token", return_value="tok"), \
             patch.object(Service, "_post_message",
                          return_value=(True, None, None, 200)), \
             patch.object(Cron, "_trigger") as trigger:
            self.env.cr.precommit.data.pop("mobile_push_dispatch_triggered", None)
            self.service._cron_dispatch_pending(batch_size=50)

        trigger.assert_not_called()

    def test_distinct_records_queue_independently(self):
        self._queue(res_id=1)
        self._queue(res_id=2)
        self.assertEqual(len(self._logs(1)), 1)
        self.assertEqual(len(self._logs(2)), 1)

    def test_dispatch_sends_and_marks_sent(self):
        self._enable_push()
        self.Token.register_token(self.user, "fcm-queue", "android")
        self._queue()

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token", return_value="tok"), \
             patch.object(Service, "_post_message",
                          return_value=(True, None, None, 200)) as post:
            self.service._cron_dispatch_pending()

        post.assert_called_once()
        log = self._logs()
        self.assertEqual(log.status, "sent")
        self.assertEqual(log.attempt_count, 1)
        self.assertTrue(log.last_attempt_at)

    def test_dispatch_without_tokens_is_skipped_not_retried(self):
        self._enable_push()
        self._queue()

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token", return_value="tok"), \
             patch.object(Service, "_post_message") as post:
            self.service._cron_dispatch_pending()

        post.assert_not_called()
        self.assertEqual(self._logs().status, "skipped")

    def test_dispatch_failure_stays_pending_for_retry(self):
        self._enable_push()
        self.Token.register_token(self.user, "fcm-queue", "android")
        self._queue()

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token", return_value="tok"), \
             patch.object(Service, "_post_message",
                          return_value=(False, "UNAVAILABLE", "later", 503)):
            self.service._cron_dispatch_pending()

        log = self._logs()
        self.assertEqual(log.status, "pending")
        self.assertEqual(log.attempt_count, 1)

    def test_dispatch_parks_row_as_failed_after_max_attempts(self):
        self._enable_push()
        self.Token.register_token(self.user, "fcm-queue", "android")
        self._queue()
        # One short of the limit, so the next run is the one that parks it.
        self._logs().write({"attempt_count": MAX_DISPATCH_ATTEMPTS - 1})

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token", return_value="tok"), \
             patch.object(Service, "_post_message",
                          return_value=(False, "UNAVAILABLE", "later", 503)):
            self.service._cron_dispatch_pending()

        self.assertEqual(self._logs().status, "failed")

    def test_dispatch_leaves_rows_pending_when_push_disabled(self):
        """Rows must survive so they go out when push is switched back on."""
        self._queue()
        Service = type(self.service)
        with patch.object(Service, "_post_message") as post:
            self.service._cron_dispatch_pending()
        post.assert_not_called()
        self.assertEqual(self._logs().status, "pending")

    def test_batch_mints_one_oauth_token_for_many_notifications(self):
        """The whole reason for batching: not one Google round-trip per push."""
        self._enable_push()
        self.Token.register_token(self.user, "fcm-queue", "android")
        for res_id in range(1, 6):
            self._queue(res_id=res_id)

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token",
                          return_value="tok") as auth, \
             patch.object(Service, "_post_message",
                          return_value=(True, None, None, 200)) as post:
            self.service._cron_dispatch_pending()

        auth.assert_called_once()
        self.assertEqual(post.call_count, 5)

    def test_one_poisoned_row_does_not_stall_the_queue(self):
        self._enable_push()
        self.Token.register_token(self.user, "fcm-queue", "android")
        self._queue(res_id=1)
        self._queue(res_id=2)

        Service = type(self.service)
        calls = {"n": 0}

        def flaky(*args, **kwargs):
            calls["n"] += 1
            if calls["n"] == 1:
                raise RuntimeError("boom")
            return (True, None, None, 200)

        with patch.object(Service, "_fetch_access_token", return_value="tok"), \
             patch.object(Service, "_post_message", side_effect=flaky):
            self.service._cron_dispatch_pending()

        self.assertEqual(calls["n"], 2, "the second row must still be attempted")
        self.assertEqual(self._logs(2).status, "sent")

    def test_unreadable_data_json_still_delivers(self):
        self._enable_push()
        self.Token.register_token(self.user, "fcm-queue", "android")
        self._queue()
        self._logs().write({"data_json": "{not json"})

        Service = type(self.service)
        with patch.object(Service, "_fetch_access_token", return_value="tok"), \
             patch.object(Service, "_post_message",
                          return_value=(True, None, None, 200)):
            self.service._cron_dispatch_pending()

        self.assertEqual(self._logs().status, "sent")
