from datetime import timedelta
from unittest.mock import patch

from odoo.fields import Datetime
from odoo.tests import TransactionCase, tagged


@tagged("post_install", "-at_install")
class TestMobileRealtimeTicket(TransactionCase):
    """Websocket tickets: single-use, short-lived, and never transferable."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.Ticket = cls.env["mobile.realtime.ticket"]
        internal = cls.env.ref("base.group_user")
        mobile = cls.env.ref("odx_mobile_connector.group_mobile_user")
        cls.user = cls.env["res.users"].create({
            "name": "rt_user@test.com", "login": "rt_user@test.com",
            "group_ids": [(4, internal.id), (4, mobile.id)],
        })
        cls.other = cls.env["res.users"].create({
            "name": "rt_other@test.com", "login": "rt_other@test.com",
            "group_ids": [(4, internal.id)],
        })

    def test_issue_returns_plaintext_but_stores_only_a_hash(self):
        ticket, expires_in = self.Ticket._issue(self.user)
        self.assertTrue(ticket)
        self.assertEqual(expires_in, 60)
        row = self.Ticket.sudo().search([("user_id", "=", self.user.id)], limit=1)
        self.assertTrue(row)
        self.assertNotEqual(
            row.ticket_hash, ticket,
            "the plaintext ticket must never be stored")
        self.assertEqual(row.ticket_hash, self.Ticket._hash(ticket))

    def test_consume_returns_the_owning_user(self):
        ticket, _ = self.Ticket._issue(self.user)
        self.assertEqual(self.Ticket._consume(ticket), self.user.id)

    def test_ticket_is_single_use(self):
        ticket, _ = self.Ticket._issue(self.user)
        self.assertEqual(self.Ticket._consume(ticket), self.user.id)
        self.assertFalse(
            self.Ticket._consume(ticket),
            "a spent ticket must not open a second connection")

    def test_expired_ticket_is_rejected(self):
        ticket, _ = self.Ticket._issue(self.user)
        row = self.Ticket.sudo().search([("user_id", "=", self.user.id)], limit=1)
        row.expires_at = Datetime.now() - timedelta(seconds=1)
        self.assertFalse(self.Ticket._consume(ticket))

    def test_unknown_and_malformed_tickets_are_rejected(self):
        for bad in ("", None, 12345, "not-a-real-ticket"):
            self.assertFalse(self.Ticket._consume(bad))

    def test_ticket_for_non_mobile_user_is_rejected(self):
        """Losing the Mobile User group between issue and use must not connect."""
        ticket, _ = self.Ticket._issue(self.user)
        self.user.write({"group_ids": [
            (3, self.env.ref("odx_mobile_connector.group_mobile_user").id)]})
        self.assertFalse(self.Ticket._consume(ticket))

    def test_ticket_for_archived_user_is_rejected(self):
        ticket, _ = self.Ticket._issue(self.user)
        self.user.active = False
        try:
            self.assertFalse(self.Ticket._consume(ticket))
        finally:
            self.user.active = True

    def test_gc_removes_old_tickets(self):
        self.Ticket._issue(self.user)
        row = self.Ticket.sudo().search([("user_id", "=", self.user.id)], limit=1)
        self.env.cr.execute(
            "UPDATE mobile_realtime_ticket SET create_date = %s WHERE id = %s",
            (Datetime.now() - timedelta(days=2), row.id),
        )
        self.env.invalidate_all()
        self.Ticket._gc_tickets()
        self.assertFalse(row.exists())


@tagged("post_install", "-at_install")
class TestMobileSyncService(TransactionCase):
    """Realtime fan-out: correct channel, correct payload, never fatal."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.service = cls.env["mobile.sync.service"]
        internal = cls.env.ref("base.group_user")
        mobile = cls.env.ref("odx_mobile_connector.group_mobile_user")
        cls.user = cls.env["res.users"].create({
            "name": "sync_user@test.com", "login": "sync_user@test.com",
            "group_ids": [(4, internal.id), (4, mobile.id)],
        })

    def test_home_sync_targets_the_users_own_partner_channel(self):
        """A recordset channel is what makes the target unforgeable."""
        with patch.object(type(self.env["res.partner"]), "_bus_send") as bus:
            self.service.notify_home(self.user, ["attendance"], reason="checkin")

        bus.assert_called_once()
        self.assertEqual(bus.call_args[0][0], "mobile_sync")
        self.assertEqual(bus.call_args[0][1]["sections"], ["attendance"])
        self.assertEqual(bus.call_args[0][1]["reason"], "checkin")

    def test_unknown_home_sections_are_dropped(self):
        with patch.object(type(self.env["res.partner"]), "_bus_send") as bus:
            self.service.notify_home(self.user, ["attendance", "not_a_section"])
        self.assertEqual(bus.call_args[0][1]["sections"], ["attendance"])

    def test_all_unknown_sections_sends_nothing(self):
        with patch.object(type(self.env["res.partner"]), "_bus_send") as bus:
            self.service.notify_home(self.user, ["bogus"])
        bus.assert_not_called()

    def test_access_sync_carries_the_full_payload_inline(self):
        with patch.object(type(self.env["res.partner"]), "_bus_send") as bus:
            self.service.notify_access(self.user, reason="test")

        bus.assert_called_once()
        self.assertEqual(bus.call_args[0][0], "mobile_access")
        access = bus.call_args[0][1]["access"]
        for key in ("user", "company", "config", "features"):
            self.assertIn(key, access, "payload must match the REST endpoint")
        self.assertEqual(access["user"]["id"], self.user.id)

    def test_revoked_user_still_receives_the_lockout_message(self):
        """The one message that matters most must not be filtered away."""
        self.user.write({"group_ids": [
            (3, self.env.ref("odx_mobile_connector.group_mobile_user").id)]})
        with patch.object(type(self.env["res.partner"]), "_bus_send") as bus:
            self.service.notify_access(self.user, reason="revoked")

        bus.assert_called_once()
        self.assertFalse(bus.call_args[0][1]["access"]["user"]["mobile_user"])

    def test_archived_user_is_not_notified(self):
        self.user.active = False
        try:
            with patch.object(type(self.env["res.partner"]), "_bus_send") as bus:
                self.service.notify_access(self.user)
            bus.assert_not_called()
        finally:
            self.user.active = True

    def test_bus_failure_never_propagates(self):
        """Realtime sync must not break the transaction that triggered it."""
        with patch.object(type(self.env["res.partner"]), "_bus_send",
                          side_effect=RuntimeError("bus down")):
            self.service.notify_home(self.user, ["attendance"])  # must not raise
            self.service.notify_access(self.user)  # must not raise

    def test_access_payload_matches_the_rest_builder(self):
        """Both transports must call the same builder -- see controllers/user.py."""
        payload = self.service._access_payload(self.user)
        self.assertEqual(
            payload["features"], self.service._feature_payload(self.user))


@tagged("post_install", "-at_install")
class TestMobileUnreadSync(TransactionCase):
    """The home bell dot is refreshed when a notification arrives or is read."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        internal = cls.env.ref("base.group_user")
        mobile = cls.env.ref("odx_mobile_connector.group_mobile_user")
        cls.user = cls.env["res.users"].create({
            "name": "unread_user@test.com", "login": "unread_user@test.com",
            "group_ids": [(4, internal.id), (4, mobile.id)],
        })

    def _log(self):
        return self.env["mobile.notification.log"].sudo().create({
            "user_id": self.user.id, "notification_type": "test_type",
            "res_model": "res.users", "res_id": self.user.id,
            "status": "pending", "title": "Hello", "message": "World",
        })

    def _sync_calls(self, bus):
        return [c for c in bus.call_args_list
                if c[0][0] == "mobile_sync"
                and c[0][1]["sections"] == ["notifications"]]

    def test_new_notification_syncs_the_owner(self):
        with patch.object(type(self.env["res.partner"]), "_bus_send") as bus:
            self._log()
        calls = self._sync_calls(bus)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][0][1]["reason"], "notification_created")

    def test_marking_read_syncs_so_other_devices_clear_the_dot(self):
        log = self._log()
        with patch.object(type(self.env["res.partner"]), "_bus_send") as bus:
            log.write({"read_at": Datetime.now()})
        calls = self._sync_calls(bus)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][0][1]["reason"], "notification_read")

    def test_delivery_updates_do_not_sync(self):
        """The dispatch cron rewrites status often; that must stay silent."""
        log = self._log()
        with patch.object(type(self.env["res.partner"]), "_bus_send") as bus:
            log.write({"status": "sent"})
        self.assertFalse(self._sync_calls(bus))

    def test_bus_failure_never_blocks_the_notification(self):
        with patch.object(type(self.env["res.partner"]), "_bus_send",
                          side_effect=RuntimeError("bus down")):
            log = self._log()
        self.assertTrue(log.exists())
