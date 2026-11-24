import hashlib
import secrets
from datetime import timedelta

from odoo import api, fields, models

TOKEN_INDEX_SIZE = 12


class MobileRefreshToken(models.Model):
    """Hashed, rotating refresh tokens for the mobile API.
    Only a SHA-256 hash is stored; a short clear-text ``token_index`` prefix speeds up lookup."""

    _name = "mobile.refresh.token"
    _description = "Mobile API Refresh Token"
    _order = "id desc"

    user_id = fields.Many2one(
        "res.users", required=True, index=True, ondelete="cascade"
    )
    token_index = fields.Char(required=True, index=True)
    token_hash = fields.Char(required=True, index=True)
    expires_at = fields.Datetime(required=True, index=True)
    revoked = fields.Boolean(default=False, index=True)
    last_used_at = fields.Datetime()
    user_agent = fields.Char()
    selected_company_ids = fields.Many2many(
        "res.company",
        "mobile_refresh_token_company_rel",
        "token_id",
        "company_id",
        string="Selected Companies",
    )

    @api.model
    def _hash_token(self, token):
        return hashlib.sha256((token or "").encode("utf-8")).hexdigest()

    @api.model
    def issue_token(self, *, user_id, expires_in_days=30, user_agent=False,
                    selected_company_ids=False):
        """Create and return ``(raw_token, record)``; the session is scoped to
        *selected_company_ids* (default: the user's primary company)."""
        token = secrets.token_urlsafe(48)
        if not selected_company_ids:
            user = self.env["res.users"].sudo().browse(user_id)
            selected_company_ids = [user.company_id.id]
        rec = self.sudo().create({
            "user_id": user_id,
            "token_index": token[:TOKEN_INDEX_SIZE],
            "token_hash": self._hash_token(token),
            "expires_at": fields.Datetime.now() + timedelta(days=expires_in_days),
            "user_agent": user_agent or False,
            "selected_company_ids": [fields.Command.set(selected_company_ids)],
        })
        return token, rec

    @api.model
    def validate_token(self, token):
        """Return the single matching, non-revoked, non-expired token or empty."""
        token = (token or "").strip()
        if not token:
            return self.browse()
        candidates = self.sudo().search([
            ("token_index", "=", token[:TOKEN_INDEX_SIZE]),
            ("revoked", "=", False),
            ("expires_at", ">=", fields.Datetime.now()),
        ])
        token_hash = self._hash_token(token)
        return candidates.filtered(lambda r: r.token_hash == token_hash)[:1]

    @api.model
    def revoke_token(self, token, *, user_id=False):
        token = (token or "").strip()
        if not token:
            return 0
        domain = [
            ("token_index", "=", token[:TOKEN_INDEX_SIZE]),
            ("token_hash", "=", self._hash_token(token)),
            ("revoked", "=", False),
        ]
        if user_id:
            domain.append(("user_id", "=", user_id))
        recs = self.sudo().search(domain)
        recs.write({"revoked": True, "last_used_at": fields.Datetime.now()})
        return len(recs)

    @api.model
    def revoke_user_tokens(self, user_id):
        recs = self.sudo().search([("user_id", "=", user_id), ("revoked", "=", False)])
        recs.write({"revoked": True, "last_used_at": fields.Datetime.now()})
        return len(recs)

    @api.model
    def _cron_cleanup(self):
        """Delete expired tokens and long-revoked ones (30-day retention)."""
        cutoff = fields.Datetime.now() - timedelta(days=30)
        self.sudo().search([
            "|",
            ("expires_at", "<", cutoff),
            "&", ("revoked", "=", True), ("create_date", "<", cutoff),
        ]).unlink()
