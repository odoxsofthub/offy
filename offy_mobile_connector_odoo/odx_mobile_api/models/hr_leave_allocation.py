import logging

from odoo import api, models

_logger = logging.getLogger(__name__)

# Fields that change the remaining-leave balance the home card shows.
HOME_RELEVANT_FIELDS = {
    "state",
    "employee_id",
    "holiday_status_id",
    "number_of_days",
    "date_from",
    "date_to",
}

# Allocations are not in the activity feed; only the balance moves.
SYNC_SECTIONS = ["time_off"]


class HrLeaveAllocation(models.Model):
    """Keeps the mobile time off balance live, since allocations change the home card's headline.
    No push: a balance change does not warrant a notification."""

    _name = "hr.leave.allocation"
    _inherit = ["hr.leave.allocation", "mobile.notify.mixin"]

    @api.model_create_multi
    def create(self, vals_list):
        allocations = super().create(vals_list)
        allocations._sync_mobile_home_for_employees(
            allocations.mapped("employee_id"), SYNC_SECTIONS,
            reason="allocation_created",
        )
        return allocations

    def write(self, vals):
        # Captured before the write: a reassigned allocation must refresh the former employee too.
        employees_before = self.mapped("employee_id")

        res = super().write(vals)

        if set(vals) & HOME_RELEVANT_FIELDS:
            self._sync_mobile_home_for_employees(
                employees_before | self.mapped("employee_id"),
                SYNC_SECTIONS,
                reason="allocation_updated",
            )
        return res

    def unlink(self):
        employees = self.mapped("employee_id")
        res = super().unlink()
        self._sync_mobile_home_for_employees(
            employees, SYNC_SECTIONS, reason="allocation_deleted")
        return res
