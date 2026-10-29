from odoo.tests import TransactionCase, tagged

from ..controllers.notification import TITLE_BY_TYPE
from ..models.hr_expense import NOTIFY_BY_PAYMENT as EXPENSE_NOTIFY_BY_PAYMENT
from ..models.hr_expense import NOTIFY_BY_STATE as EXPENSE_NOTIFY_BY_STATE
from ..models.hr_leave import NOTIFY_BY_STATE as LEAVE_NOTIFY_BY_STATE
from ..models.hr_payslip import PAYSLIP_NOTIFICATION_TYPE
from ..notifications import NOTIFICATION_TITLES


def _queueable_types():
    """Every notification type any trigger can queue, read off the triggers
    themselves. Expenses have two surfaces: the state maps AND the payment one.
    """
    types = {PAYSLIP_NOTIFICATION_TYPE}
    for state_map in (LEAVE_NOTIFY_BY_STATE, EXPENSE_NOTIFY_BY_STATE):
        types.update(entry[0] for entry in state_map.values())
    types.update(EXPENSE_NOTIFY_BY_PAYMENT)
    return types


@tagged("-at_install", "post_install")
class TestNotificationCatalogue(TransactionCase):
    """The push triggers and the inbox endpoint must name the same set of types.
    A mismatch raises nothing, it just shows "Notification" as the title, so only a test catches it."""

    def test_every_queueable_type_has_a_title(self):
        missing = sorted(_queueable_types() - set(NOTIFICATION_TITLES))
        self.assertFalse(
            missing,
            "these notification types can be queued by a trigger but have no "
            "title in notifications.py: %s" % ", ".join(missing))

    def test_inbox_endpoint_reads_the_shared_catalogue(self):
        """The inbox uses the same catalogue object, not an equal copy."""
        self.assertIs(TITLE_BY_TYPE, NOTIFICATION_TITLES)

    def test_catalogue_has_no_unused_entries(self):
        """Every catalogue title has a trigger (else it was removed or renamed on one side)."""
        orphans = sorted(set(NOTIFICATION_TITLES) - _queueable_types())
        self.assertFalse(
            orphans,
            "these titles are declared but no trigger queues them: %s"
            % ", ".join(orphans))

    def test_titles_are_non_empty(self):
        for notification_type, title in NOTIFICATION_TITLES.items():
            self.assertTrue(
                (title or "").strip(),
                "%s has a blank title" % notification_type)

    def test_in_payment_does_not_notify(self):
        """`in_payment` must not send the "Expense Paid" notification; only `paid` does."""
        self.assertNotIn("in_payment", EXPENSE_NOTIFY_BY_STATE)
        self.assertIn("paid", EXPENSE_NOTIFY_BY_STATE)
        self.assertEqual(
            EXPENSE_NOTIFY_BY_STATE["paid"][0], "expense_paid")

    def test_the_seven_known_triggers_are_all_present(self):
        """Pins the actual set: the checks above are self-referential and would
        pass if a trigger were deleted along with its title.
        """
        self.assertEqual(
            _queueable_types(),
            {
                "payslip_available",
                "timeoff_approved",
                "timeoff_refused",
                "expense_approved",
                "expense_refused",
                "expense_paid",
                "expense_partially_paid",
            },
        )

    def test_the_payment_trigger_types_are_really_queueable(self):
        """`NOTIFY_BY_PAYMENT` must stay in step with what the payment trigger
        sets, and every type in it must have a title."""
        self.assertIn("expense_partially_paid", _queueable_types())
        self.assertIn("expense_paid", _queueable_types())
        for notification_type in EXPENSE_NOTIFY_BY_PAYMENT:
            self.assertIn(
                notification_type, NOTIFICATION_TITLES,
                "%s is queued by the payment trigger but has no title"
                % notification_type)
