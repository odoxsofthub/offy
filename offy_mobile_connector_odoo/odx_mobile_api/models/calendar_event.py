import logging

from odoo import api, models

_logger = logging.getLogger(__name__)

# Fields that change what the mobile calendar card shows.
HOME_RELEVANT_FIELDS = {
    "name",
    "start",
    "stop",
    "allday",
    "active",
    "user_id",
    "partner_ids",
}

SYNC_SECTIONS = ["calendar"]


class CalendarEvent(models.Model):
    """Keeps the mobile calendar card live via a silent sync (no push; Odoo already mails attendees).
    Audience is partner-based (organiser plus attendees), matching the mobile calendar query.
    """

    _name = "calendar.event"
    _inherit = ["calendar.event", "mobile.notify.mixin"]

    def _mobile_audience(self):
        """Users who can see these events on their mobile calendar."""
        users = self.mapped("user_id")
        users |= self.mapped("partner_ids.user_ids")
        return users

    @api.model_create_multi
    def create(self, vals_list):
        events = super().create(vals_list)
        events._sync_mobile_home_for_users(
            events._mobile_audience(), SYNC_SECTIONS, reason="event_created")
        return events

    def write(self, vals):
        # Captured before the write: a removed attendee must be refreshed too.
        audience_before = self._mobile_audience()

        res = super().write(vals)

        if set(vals) & HOME_RELEVANT_FIELDS:
            self._sync_mobile_home_for_users(
                audience_before | self._mobile_audience(),
                SYNC_SECTIONS,
                reason="event_updated",
            )
        return res

    def unlink(self):
        # Capture before the rows go; afterwards the audience can no longer be resolved.
        audience = self._mobile_audience()
        res = super().unlink()
        self._sync_mobile_home_for_users(
            audience, SYNC_SECTIONS, reason="event_deleted")
        return res
