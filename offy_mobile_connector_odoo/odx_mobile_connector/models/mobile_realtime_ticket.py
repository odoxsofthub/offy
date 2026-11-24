import hashlib
import logging
import secrets
from datetime import timedelta

from odoo import api, fields, models

_logger = logging.getLogger(__name__)

# Long enough that guessing is hopeless, short-lived enough that a leaked one is useless.
TICKET_BYTES = 32
TICKET_TTL_SECONDS = 60


class MobileRealtimeTicket(models.Model):
    """Single-use, one-minute ticket that bridges a Bearer token to Odoo's cookie-only ``/websocket`` auth.
    Keeps the API key out of handshake URLs (logged by proxies); only its SHA-256 is stored."""

    _name = "mobile.realtime.ticket"
    _description = "Mobile Realtime Websocket Ticket"
    _order = "create_date desc"

    user_id = fields.Many2one(
        "res.users", string="User", required=True, index=True, ondelete="cascade",
    )
    ticket_hash = fields.Char(
        string="Ticket Hash", required=True, index=True,
        help="SHA-256 of the issued ticket. The ticket itself is never stored.",
    )
    expires_at = fields.Datetime(string="Expires At", required=True, index=True)
    used_at = fields.Datetime(
        string="Used At",
        help="Set the moment the ticket opens a websocket. A ticket is "
             "single-use: a second attempt is rejected.",
    )

    _ticket_hash_unique = models.Constraint(
        "UNIQUE(ticket_hash)", "Realtime ticket collision.",
    )

    @staticmethod
    def _hash(ticket):
        return hashlib.sha256(ticket.encode("utf-8")).hexdigest()

    @api.model
    def _issue(self, user):
        """Mint a ticket for *user*; returns ``(ticket, expires_in_seconds)``, plaintext shown once only."""
        ticket = secrets.token_urlsafe(TICKET_BYTES)
        self.sudo().create({
            "user_id": user.id,
            "ticket_hash": self._hash(ticket),
            "expires_at": fields.Datetime.now() + timedelta(seconds=TICKET_TTL_SECONDS),
        })
        return ticket, TICKET_TTL_SECONDS

    @api.model
    def _consume(self, ticket):
        """Validate and burn a ticket; returns the user id or False, never saying why it failed."""
        if not ticket or not isinstance(ticket, str):
            return False
        record = self.sudo().search([
            ("ticket_hash", "=", self._hash(ticket)),
            ("used_at", "=", False),
            ("expires_at", ">", fields.Datetime.now()),
        ], limit=1)
        if not record:
            return False
        # Burn before returning: a ticket must not survive to open a second connection.
        record.write({"used_at": fields.Datetime.now()})
        user = record.user_id
        if not user.active or not user.sudo().has_group(
            "odx_mobile_connector.group_mobile_user"
        ):
            return False
        return user.id

    @api.model
    def _gc_tickets(self):
        """Cron: delete spent and expired tickets (tickets live 60 seconds)."""
        cutoff = fields.Datetime.now() - timedelta(days=1)
        stale = self.sudo().search([("create_date", "<", cutoff)])
        count = len(stale)
        stale.unlink()
        if count:
            _logger.info("Removed %s expired realtime ticket(s).", count)
        return count
