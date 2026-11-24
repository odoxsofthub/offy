import logging

from odoo import models
from odoo.addons.bus.websocket import wsrequest

_logger = logging.getLogger(__name__)

# Query-string key the Flutter client puts its one-time ticket in when opening the websocket.
TICKET_PARAM = "ticket"


class IrWebsocket(models.AbstractModel):
    """Lets a Bearer-authenticated mobile client open a websocket via a single-use ticket.
    Odoo only authenticates ``/websocket`` by session cookie; without a ticket the default path is unchanged."""

    _inherit = "ir.websocket"

    @classmethod
    def _authenticate(cls):
        ticket = None
        try:
            ticket = wsrequest.httprequest.args.get(TICKET_PARAM)
        except Exception:
            # Defensive: never let ticket parsing break the normal web path.
            ticket = None

        if ticket:
            # sudo(): the ticket table has no ACL for an unauthenticated connection.
            uid = wsrequest.env["mobile.realtime.ticket"].sudo()._consume(ticket)
            if uid:
                wsrequest.session.uid = uid
                wsrequest.update_env(user=uid)
                return
            # An invalid ticket is only logged; the connection then continues unauthenticated via super().
            _logger.info("Rejected websocket connection: invalid realtime ticket.")

        super()._authenticate()

    def _build_bus_channel_list(self, channels):
        """Subscribe a ticket-authenticated user to their own partner channel.
        The channel must stay a recordset: client-supplied string channels are not allow-listed, so a string would be guessable."""
        channels = super()._build_bus_channel_list(channels)
        user = self.env.user
        if user and not user._is_public() and user.partner_id:
            has_partner_channel = any(
                getattr(channel, "_name", None) == "res.partner"
                and channel == user.partner_id
                for channel in channels
            )
            if not has_partner_channel:
                channels.append(user.partner_id)
        return channels
