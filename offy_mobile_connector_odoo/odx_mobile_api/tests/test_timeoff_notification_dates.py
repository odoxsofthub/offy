from datetime import date, timedelta
from unittest.mock import patch

from odoo.tests import TransactionCase, tagged


def _next_monday(base=None):
    """First Monday at least a week out -- keeps test dates on working days."""
    base = base or date.today()
    target = base + timedelta(days=7)
    return target + timedelta(days=(7 - target.weekday()) % 7)


@tagged("post_install", "-at_install")
class TestTimeoffNotificationDates(TransactionCase):
    """The approved/refused push must name the dates it decided, since the leave type alone is not an identifier."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        LeaveType = cls.env["hr.leave.type"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        base_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.user = Users.create({
            "name": "Timeoff Notify User",
            "login": "timeoff_notify_dates@test.com",
            "group_ids": [(4, mobile_group.id), (4, base_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Timeoff Notify User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })
        cls.leave_type = LeaveType.create({
            "name": "Annual Leave",
            "requires_allocation": False,
            "request_unit": "day",
            "leave_validation_type": "hr",
        })
        cls.day = _next_monday()

    def _leave(self, start, end=None):
        return self.env["hr.leave"].sudo().create({
            "employee_id": self.employee.id,
            "holiday_status_id": self.leave_type.id,
            "request_date_from": start,
            "request_date_to": end or start,
        })

    def _label(self, start, end=None):
        return self._leave(start, end)._mobile_leave_date_label()

    def _queued_bodies(self, leave, state):
        """Force `leave` into `state` and return the queued push bodies (the push service is mocked)."""
        bodies = []

        def _capture(user, notification_type, model, res_id, title, body, **kw):
            bodies.append(body)
            return True

        with patch.object(
            type(self.env["mobile.push.service"]),
            "queue_once_to_user",
            side_effect=_capture,
        ):
            leave.sudo().write({"state": state})
        return bodies

    def test_single_day_label(self):
        day = date(2026, 8, 7)
        # No zero padding: "7 Aug", not "07 Aug".
        self.assertEqual(self._label(day), "7 Aug 2026")

    def test_range_within_one_month_collapses_month_and_year(self):
        self.assertEqual(
            self._label(date(2026, 8, 7), date(2026, 8, 9)),
            "7-9 Aug 2026",
        )

    def test_range_across_months_keeps_both_months(self):
        self.assertEqual(
            self._label(date(2026, 8, 30), date(2026, 9, 2)),
            "30 Aug - 2 Sep 2026",
        )

    def test_range_across_years_keeps_both_years(self):
        self.assertEqual(
            self._label(date(2026, 12, 30), date(2027, 1, 2)),
            "30 Dec 2026 - 2 Jan 2027",
        )

    def test_missing_start_date_yields_empty_label(self):
        """No start date degrades to "", never a broken range; the blank has to be forced since Odoo defaults it to today."""
        leave = self.env["hr.leave"].sudo().new({
            "employee_id": self.employee.id,
            "holiday_status_id": self.leave_type.id,
        })
        leave.request_date_from = False
        self.assertEqual(leave._mobile_leave_date_label(), "")

    def test_reversed_range_does_not_render_backwards(self):
        """A reversed range collapses to the start day rather than "9-7 Aug"."""
        leave = self.env["hr.leave"].sudo().new({
            "employee_id": self.employee.id,
            "holiday_status_id": self.leave_type.id,
            "request_date_from": date(2026, 8, 9),
            "request_date_to": date(2026, 8, 7),
        })
        self.assertEqual(leave._mobile_leave_date_label(), "9 Aug 2026")

    def test_two_same_type_leaves_produce_distinguishable_bodies(self):
        """The reported bug: same type, different dates, identical text."""
        first = self._leave(self.day)
        second = self._leave(self.day + timedelta(days=14))

        first_bodies = self._queued_bodies(first, "validate")
        second_bodies = self._queued_bodies(second, "validate")

        self.assertEqual(len(first_bodies), 1)
        self.assertEqual(len(second_bodies), 1)
        self.assertNotEqual(
            first_bodies[0], second_bodies[0],
            "Two approvals of the same leave type must not read identically.",
        )
        # Each body names its OWN date, not merely some date.
        self.assertIn(first._mobile_leave_date_label(), first_bodies[0])
        self.assertIn(second._mobile_leave_date_label(), second_bodies[0])

    def test_approved_body_names_type_and_dates(self):
        leave = self._leave(self.day)
        bodies = self._queued_bodies(leave, "validate")
        self.assertEqual(
            bodies[0],
            "Your Annual Leave for %s has been approved."
            % leave._mobile_leave_date_label(),
        )

    def test_refused_body_names_type_and_dates(self):
        leave = self._leave(self.day)
        bodies = self._queued_bodies(leave, "refuse")
        self.assertEqual(
            bodies[0],
            "Your Annual Leave for %s has been refused."
            % leave._mobile_leave_date_label(),
        )
