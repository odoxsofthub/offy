import logging

from odoo import api, models

_logger = logging.getLogger(__name__)


class HrAttendance(models.Model):
    """Keeps the mobile home attendance card live on every device, including check-ins made elsewhere.
    Silent sync only: a push echoing the user's own action would be noise.
    """

    _name = "hr.attendance"
    _inherit = ["hr.attendance", "mobile.notify.mixin"]

    def _sync_attendance_home(self, reason):
        for attendance in self:
            attendance._sync_mobile_home(
                attendance.employee_id, ["attendance", "activities"],
                reason=reason,
            )

    @api.model_create_multi
    def create(self, vals_list):
        attendances = super().create(vals_list)
        attendances._sync_attendance_home("attendance_checkin")
        return attendances

    def write(self, vals):
        res = super().write(vals)
        # check_out/check_in flip the home card between "checked in" and "checked out".
        if "check_out" in vals or "check_in" in vals:
            self._sync_attendance_home("attendance_checkout")
        return res

    def unlink(self):
        # Capture before the rows go; afterwards there is no employee left to refresh.
        employees = self.mapped("employee_id")
        res = super().unlink()
        for employee in employees:
            self.env["mobile.sync.service"].notify_home(
                employee.user_id, ["attendance", "activities"],
                reason="attendance_deleted",
            )
        return res
