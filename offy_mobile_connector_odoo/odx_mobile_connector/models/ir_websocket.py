import logging
from datetime import timedelta

from odoo import fields, models
from odoo.tools import SQL

from odoo.addons.bus.websocket import wsrequest

_logger = logging.getLogger(__name__)

# Query-string key the Flutter client puts its one-time ticket in when opening the websocket.
TICKET_PARAM = "ticket"

# Odoo 19 replayed only this many seconds of history to a `last: 0` subscriber (bus TIMEOUT);
# Odoo 20 replays everything still kept (24 h). Mobile sockets keep the v19 window.
MOBILE_INITIAL_REPLAY_SECONDS = 50


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

    def _subscribe(self, og_data):
        """Accept the mobile client's ``{channels, last}`` subscribe payload.
        Odoo 20 reads ``og_data["check_outdated"]``, which only the web client sends; default it to False."""
        if isinstance(og_data, dict) and "check_outdated" not in og_data:
            og_data = dict(og_data, check_outdated=False)
        if (isinstance(og_data, dict) and og_data.get("last") == 0
                and self._is_mobile_ticket_socket()):
            og_data = dict(og_data, last=self._mobile_replay_floor_id())
        return super()._subscribe(og_data)

    def _is_mobile_ticket_socket(self):
        """True for a socket opened with a mobile ticket by a signed-in user; the web client never sends one."""
        try:
            has_ticket = bool(wsrequest.httprequest.args.get(TICKET_PARAM))
        except RuntimeError:
            # No websocket request bound (e.g. called from a test).
            return False
        return has_ticket and not self.env.user._is_public()

    def _mobile_replay_floor_id(self):
        """Id of the newest bus notification older than the v19 replay window, or 0.
        Subscribing from it replays only the last ``MOBILE_INITIAL_REPLAY_SECONDS``, as Odoo 19 did for ``last: 0``.
        Plain SQL on ids only: no message content is read and no sudo() is needed."""
        cutoff = fields.Datetime.now() - timedelta(seconds=MOBILE_INITIAL_REPLAY_SECONDS)
        self.env.cr.execute(SQL(
            "SELECT id FROM bus_bus WHERE create_date <= %s ORDER BY id DESC LIMIT 1", cutoff,
        ))
        row = self.env.cr.fetchone()
        return row[0] if row else 0

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
