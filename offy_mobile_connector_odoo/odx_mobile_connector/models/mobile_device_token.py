import logging
from datetime import timedelta

from odoo import _, api, fields, models
from odoo.exceptions import ValidationError

_logger = logging.getLogger(__name__)

DEVICE_TYPES = [
    ("android", "Android"),
    ("ios", "iOS"),
    ("web", "Web"),
    ("unknown", "Unknown"),
]

# Why a token was deactivated.
REMOVED_REASONS = [
    ("permanent_firebase_failure", "Permanent Firebase Failure"),
    ("temporary_failure_threshold", "Temporary Failure Threshold Exceeded"),
    ("manual", "Manually Removed"),
    ("logout", "Signed Out"),
    # Distinct from "logout": a credential change evicted every device at once,
    # so admins can tell a reset account from a user signing out.
    ("password_changed", "Password Changed"),
]

TOKEN_STATUSES = [
    ("active", "Active"),
    ("warning", "Warning"),
    ("failed", "Failed"),
    ("removed", "Removed"),
]


class MobileDeviceToken(models.Model):
    """A single Firebase/FCM push token belonging to one mobile session.
    Written only by odx_mobile_api via sudo(): ``group_mobile_user`` has no ACL on this model."""

    _name = "mobile.device.token"
    _description = "Mobile Device Push Token"
    _order = "updated_at desc"
    _rec_name = "firebase_id"

    session_id = fields.Many2one(
        "mobile.user.session",
        string="Session",
        required=True,
        index=True,
        ondelete="cascade",
    )
    user_id = fields.Many2one(
        related="session_id.user_id", store=True, index=True, readonly=True
    )
    firebase_id = fields.Char(string="Firebase ID", required=True, index=True)
    device_type = fields.Selection(
        DEVICE_TYPES, string="Device Type", default="unknown", required=True
    )
    updated_at = fields.Datetime(
        string="Updated At", default=fields.Datetime.now, required=True
    )
    registered_at = fields.Datetime(
        string="Registered",
        default=fields.Datetime.now,
        required=True,
        help="When this token line was first stored for the current owner. "
             "Re-registering the same token updates Updated At but keeps this "
             "date unchanged.",
    )
    active = fields.Boolean(default=True)
    status = fields.Selection(
        TOKEN_STATUSES,
        string="Status",
        compute="_compute_status",
    )

    # Firebase delivery failure-tracking, used by mobile.push.service to decide token deactivation.
    last_push_sent_at = fields.Datetime(string="Last Notification Sent")
    failure_count = fields.Integer(string="Failure Count", default=0)
    last_failure_at = fields.Datetime(string="Last Failure At")
    last_failure_code = fields.Char(string="Last Failure Code")
    last_failure_message = fields.Char(string="Last Failure Message")
    last_success_at = fields.Datetime(string="Last Success At")
    removed_reason = fields.Selection(REMOVED_REASONS, string="Removed Reason")
    removed_at = fields.Datetime(string="Removed At")

    @api.depends("active", "failure_count", "removed_reason", "removed_at")
    def _compute_status(self):
        # Read the configured limit once, not per token.
        config = self.env["mobile.config"].sudo().search([], limit=1)
        limit = (config.firebase_token_failure_limit if config else 0) or 5
        for token in self:
            if not token.active:
                token.status = "removed"
            elif token.failure_count >= limit:
                token.status = "failed"
            elif token.failure_count:
                token.status = "warning"
            else:
                token.status = "active"

    @api.constrains("firebase_id", "active")
    def _check_firebase_unique(self):
        """One Firebase token may belong to only one active row at a time.
        sudo() search is narrowed to the exact firebase_id, since users cannot read others' rows."""
        for record in self:
            if not record.active or not record.firebase_id:
                continue
            duplicate = self.sudo().search_count([
                ("id", "!=", record.id),
                ("firebase_id", "=", record.firebase_id),
                ("active", "=", True),
            ])
            if duplicate:
                raise ValidationError(
                    _("Firebase token '%s' is already registered.", record.firebase_id)
                )

    @api.model
    def register_token(self, user, firebase_id, device_type):
        """Add or update *user*'s Firebase token, enforcing global uniqueness and ``max_devices``.
        Called by the device-token controller for the authenticated user only."""
        firebase_id = (firebase_id or "").strip()
        if not firebase_id:
            raise ValidationError(_("Firebase ID is required."))

        now = fields.Datetime.now()
        Token = self.sudo()
        Session = self.env["mobile.user.session"].sudo()

        session = Session.search([("user_id", "=", user.id)], limit=1)
        if not session:
            session = Session.create(
                {"user_id": user.id, "first_login": now, "last_session": now}
            )
        else:
            session.write({"last_session": now})

        # Global uniqueness: at most one active row may hold this exact token.
        existing = Token.search([("firebase_id", "=", firebase_id)], limit=1)
        if existing and existing.user_id != user:
            # Newest login/device registration wins: detach the old owner.
            existing.write({"active": False})
            existing = Token.browse()

        if existing:
            existing.write({
                "session_id": session.id,
                "device_type": device_type,
                "updated_at": now,
            })
            record = existing
        else:
            record = Token.create({
                "session_id": session.id,
                "firebase_id": firebase_id,
                "device_type": device_type,
                "updated_at": now,
                "registered_at": now,
            })

        self._enforce_max_devices(user, record)
        return record

    @api.model
    def _enforce_max_devices(self, user, keep):
        """Deactivate the oldest tokens beyond ``mobile.config.max_devices`` (<= 0 means unlimited)."""
        config = self.env["mobile.config"].sudo().get_config()
        max_devices = config.max_devices
        if max_devices <= 0:
            return
        tokens = self.sudo().search(
            [("session_id.user_id", "=", user.id)], order="updated_at asc, id asc"
        )
        overflow = len(tokens) - max_devices
        if overflow > 0:
            (tokens - keep)[:overflow].write({"active": False})

    @api.model
    def deactivate_on_logout(self, user, firebase_id=None):
        """Deactivate the signed-out device's push token(s) for *user*; return what was deactivated.
        Without *firebase_id*, all tokens are dropped only when max_devices is 1, else a warning is logged."""
        Token = self.sudo()
        domain = [("session_id.user_id", "=", user.id), ("active", "=", True)]

        if firebase_id:
            firebase_id = firebase_id.strip()
        if firebase_id:
            domain.append(("firebase_id", "=", firebase_id))
        else:
            config = self.env["mobile.config"].sudo().get_config()
            max_devices = config.max_devices if config else 1
            if max_devices != 1:
                _logger.warning(
                    "Logout for user %s did not supply firebase_id and "
                    "max_devices=%s allows more than one device; leaving push "
                    "tokens active. Update the client to send its Firebase "
                    "token on logout.",
                    user.id, max_devices)
                return Token.browse()

        tokens = Token.search(domain)
        if not tokens:
            return tokens
        tokens.write({
            "active": False,
            "removed_reason": "logout",
            "removed_at": fields.Datetime.now(),
        })
        return tokens

    def action_remove(self):
        """Backend "remove" button: archive the token and stamp ``removed_reason``/``removed_at``."""
        self.write({
            "active": False,
            "removed_reason": "manual",
            "removed_at": fields.Datetime.now(),
        })

    @api.model
    def _cron_cleanup_stale_tokens(self):
        """Cron backstop: deactivate tokens at the failure threshold that are still active.
        Cleanup only, never sends; recovered tokens have ``failure_count`` reset and are excluded."""
        # sudo(): the cron has no user/request context and group_mobile_user cannot read the config.
        config = self.env["mobile.config"].sudo().get_config()
        if not config.firebase_token_auto_deactivate_failed:
            return
        limit = config.firebase_token_failure_limit or 5
        window_hours = config.firebase_token_failure_window_hours or 72
        cutoff = fields.Datetime.now() - timedelta(hours=window_hours)

        stale = self.sudo().search([
            ("active", "=", True),
            ("failure_count", ">=", limit),
            ("last_failure_at", "<=", cutoff),
        ])
        if stale:
            stale.write({
                "active": False,
                "removed_reason": "temporary_failure_threshold",
                "removed_at": fields.Datetime.now(),
            })
