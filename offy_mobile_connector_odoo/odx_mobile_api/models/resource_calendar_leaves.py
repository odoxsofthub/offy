import logging

from odoo import api, models

_logger = logging.getLogger(__name__)

HOME_RELEVANT_FIELDS = {
    "name",
    "date_from",
    "date_to",
    "company_id",
    "resource_id",
    "calendar_id",
}

SYNC_SECTIONS = ["calendar"]


class ResourceCalendarLeaves(models.Model):
    """Keeps public holidays live on the mobile calendar card for every user of the company.
    Rows with `resource_id` set are personal time off, not holidays, and are skipped."""

    _name = "resource.calendar.leaves"
    _inherit = ["resource.calendar.leaves", "mobile.notify.mixin"]

    def _mobile_audience(self):
        """Mobile users affected: everyone for a company-less row, else that company's mobile users."""
        holidays = self.filtered(lambda leave: not leave.resource_id)
        if not holidays:
            return self.env["res.users"]

        group = self.env.ref(
            "odx_mobile_connector.group_mobile_user", raise_if_not_found=False)
        if not group:
            return self.env["res.users"]

        # sudo(): reading the group's membership to find who to refresh.
        users = group.sudo().user_ids
        companies = holidays.mapped("company_id")
        if not all(holidays.mapped("company_id")):
            # At least one row is global: everyone is affected.
            return users
        return users.filtered(lambda u: u.company_id in companies)

    @api.model_create_multi
    def create(self, vals_list):
        leaves = super().create(vals_list)
        leaves._sync_mobile_home_for_users(
            leaves._mobile_audience(), SYNC_SECTIONS, reason="holiday_created")
        return leaves

    def write(self, vals):
        audience_before = self._mobile_audience()
        res = super().write(vals)
        if set(vals) & HOME_RELEVANT_FIELDS:
            self._sync_mobile_home_for_users(
                audience_before | self._mobile_audience(),
                SYNC_SECTIONS,
                reason="holiday_updated",
            )
        return res

    def unlink(self):
        audience = self._mobile_audience()
        res = super().unlink()
        self._sync_mobile_home_for_users(
            audience, SYNC_SECTIONS, reason="holiday_deleted")
        return res
