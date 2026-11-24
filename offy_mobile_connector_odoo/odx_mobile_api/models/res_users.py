import logging

from odoo import fields, models
from odoo.tools import SQL

_logger = logging.getLogger(__name__)


class ResUsers(models.Model):
    _inherit = "res.users"

    def _mobile_revoke_sessions(self, reason="password_changed"):
        """Also revoke the API layer's mobile refresh tokens and `mobile_api`-scoped API keys on logout.
        API keys are deleted in raw SQL because res.users.apikeys has no unlink ACL; other-scope keys are kept.
        """
        super()._mobile_revoke_sessions(reason=reason)
        if not self.ids:
            return

        # Imported lazily: `controllers/` loads after `models/`, so a top-level import would be a cycle.
        from ..controllers.main import API_KEY_SCOPE  # noqa: PLC0415

        refresh_tokens = self.env["mobile.refresh.token"].sudo().search([
            ("user_id", "in", self.ids),
            ("revoked", "=", False),
        ])
        if refresh_tokens:
            refresh_tokens.write({
                "revoked": True,
                "last_used_at": fields.Datetime.now(),
            })

        keys_table = self.env["res.users.apikeys"].sudo()._table
        self.env.cr.execute(SQL(
            "DELETE FROM %s WHERE user_id = ANY(%s) AND scope = %s",
            SQL.identifier(keys_table), list(self.ids), API_KEY_SCOPE,
        ))
        revoked_keys = self.env.cr.rowcount
        self.env["res.users.apikeys"].sudo().invalidate_model()

        if refresh_tokens or revoked_keys:
            _logger.info(
                "Mobile sessions revoked for user(s) %s (reason=%s): "
                "%s access token(s), %s refresh token(s).",
                self.ids, reason, revoked_keys, len(refresh_tokens),
            )
