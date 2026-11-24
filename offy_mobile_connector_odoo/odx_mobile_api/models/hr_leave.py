import logging

from odoo import api, models

from ..notifications import (
    NOTIFICATION_TITLES, TIMEOFF_APPROVED, TIMEOFF_REFUSED,
)

_logger = logging.getLogger(__name__)

TIME_OFF_FEATURE_CODE = "time_off"

# Fields that change what the mobile home time off card shows.
HOME_RELEVANT_FIELDS = {
    "state",
    "employee_id",
    "holiday_status_id",
    "number_of_days",
    "request_date_from",
    "request_date_to",
    "date_from",
    "date_to",
}

# "calendar" is included because approved leave also appears on the calendar card.
SYNC_SECTIONS = ["time_off", "calendar", "activities"]

# Terminal hr.leave states (for the employee) -> (notification type, title, verb).
NOTIFY_BY_STATE = {
    "validate": (TIMEOFF_APPROVED, NOTIFICATION_TITLES[TIMEOFF_APPROVED],
                 "approved"),
    "refuse": (TIMEOFF_REFUSED, NOTIFICATION_TITLES[TIMEOFF_REFUSED],
               "refused"),
}

# Half-day suffix, so a morning and an afternoon request on the same date stay distinguishable.
HALF_DAY_PERIODS = {"am": "morning", "pm": "afternoon"}


def _day_str(value):
    """`date` -> "7 Aug 2026" (no zero padding, unambiguous year)."""
    return "%s %s %s" % (value.day, value.strftime("%b"), value.year)


class HrLeave(models.Model):
    """Queues a push when a time off request is approved or refused.
    Hooks write() and queues via the shared mixin so approvals never wait on or fail from Firebase."""

    _name = "hr.leave"
    _inherit = ["hr.leave", "mobile.notify.mixin"]

    @api.model_create_multi
    def create(self, vals_list):
        leaves = super().create(vals_list)
        # A new request consumes balance and shows in the activity feed straight away.
        leaves._sync_mobile_home_for_employees(
            leaves.mapped("employee_id"), SYNC_SECTIONS,
            reason="leave_created",
        )
        return leaves

    def unlink(self):
        # Capture before the rows go; afterwards there is no employee left to refresh.
        employees = self.mapped("employee_id")
        res = super().unlink()
        self._sync_mobile_home_for_employees(
            employees, SYNC_SECTIONS, reason="leave_deleted")
        return res

    def write(self, vals):
        # Only snapshot when this write could reach a notifying state.
        track = "state" in vals and vals["state"] in NOTIFY_BY_STATE
        before = {leave.id: leave.state for leave in self} if track else None

        # Captured before the write: a reassigned request must refresh the former employee too.
        employees_before = self.mapped("employee_id")

        res = super().write(vals)

        if before:
            for leave in self:
                # Only on a real transition: re-saving an approved leave must not re-notify.
                if leave.state == before.get(leave.id):
                    continue
                leave._notify_mobile_leave_state()

        # Deliberately wider than the push trigger: the home card reflects more fields.
        if set(vals) & HOME_RELEVANT_FIELDS:
            self._sync_mobile_home_for_employees(
                employees_before | self.mapped("employee_id"),
                SYNC_SECTIONS,
                reason="leave_updated",
            )
        return res

    def _mobile_leave_date_label(self):
        """Compact date label for the request, e.g. "7-9 Aug 2026" or "7 Aug 2026 (morning)".
        Returns "" when there is no start date; the caller then omits the dates."""
        self.ensure_one()
        start = self.request_date_from
        if not start:
            return ""
        end = self.request_date_to or start
        if end < start:
            # Defensive: a reversed range would otherwise render backwards.
            end = start

        if start == end:
            if self.request_unit_half:
                period = HALF_DAY_PERIODS.get(self.request_date_from_period)
                if period:
                    return "%s (%s)" % (_day_str(start), period)
            return _day_str(start)
        if (start.year, start.month) == (end.year, end.month):
            return "%s-%s" % (start.day, _day_str(end))
        if start.year == end.year:
            return "%s %s - %s" % (
                start.day, start.strftime("%b"), _day_str(end))
        return "%s - %s" % (_day_str(start), _day_str(end))

    def _notify_mobile_leave_state(self):
        for leave in self:
            entry = NOTIFY_BY_STATE.get(leave.state)
            if not entry:
                continue
            notification_type, title, verb = entry
            leave_type = leave.holiday_status_id.name or "Time off"
            dates = leave._mobile_leave_date_label()
            if dates:
                body = "Your %s for %s has been %s." % (leave_type, dates, verb)
            else:
                body = "Your %s has been %s." % (leave_type, verb)
            leave._queue_mobile_notification(
                leave.employee_id,
                TIME_OFF_FEATURE_CODE,
                notification_type,
                title,
                body,
                data={
                    "leave_id": leave.id,
                    "state": leave.state,
                    # Dates are echoed so the client can label inbox rows without a lookup.
                    "date_from": leave.request_date_from.isoformat()
                                 if leave.request_date_from else False,
                    "date_to": leave.request_date_to.isoformat()
                               if leave.request_date_to else False,
                    "date_label": dates,
                    "action": "open_time_off_detail",
                },
                # A leave can be re-decided; write_date keeps each decision distinct.
                dedup_key="leave:%s:%s:%s" % (
                    leave.id, leave.state, leave.write_date or ""),
            )
