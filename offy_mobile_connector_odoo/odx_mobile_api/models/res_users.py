import logging

from odoo import api, fields, models
from odoo.fields import Command
from odoo.tools import SQL

_logger = logging.getLogger(__name__)

MOBILE_USER_GROUP = "odx_mobile_connector.group_mobile_user"
# Odoo 20 grants hr.leave / hr.work.entry.type access only to this group (v19 used base.group_user).
TIME_OFF_GROUP = "hr_holidays.group_hr_holidays_employee"


class ResUsers(models.Model):
    _inherit = "res.users"

    def _mobile_grant_time_off_group(self):
        """Add the time off Employee group to the users in `self` who don't hold it, directly or implied.
        Runs in the caller's env: whoever may grant Mobile User may also grant this group, so no sudo().
        Returns the users that were changed."""
        group = self.env.ref(TIME_OFF_GROUP, raise_if_not_found=False)
        if not group:
            return self.browse()
        missing = self.filtered(lambda user: not user.share and group not in user.all_group_ids)
        if missing:
            missing.write({"group_ids": [Command.link(group.id)]})
        return missing

    @api.model
    def _mobile_grant_time_off_group_to_mobile_users(self):
        """Give the time off group to every active mobile user lacking it (upgrade and install)."""
        mobile_group = self.env.ref(MOBILE_USER_GROUP, raise_if_not_found=False)
        if not mobile_group:
            return self.browse()
        users = self.search([("group_ids", "in", mobile_group.id)])
        return users._mobile_grant_time_off_group()

    @api.model_create_multi
    def create(self, vals_list):
        users = super().create(vals_list)
        mobile_group = self.env.ref(MOBILE_USER_GROUP, raise_if_not_found=False)
        if mobile_group:
            users.filtered(lambda user: mobile_group in user.group_ids)._mobile_grant_time_off_group()
        return users

    def write(self, vals):
        """Grant the time off group only when a user newly becomes a Mobile User, so an admin who
        later removes it from a mobile user doesn't see it come back on unrelated writes.
        The connector's `mobile_user` inverse writes `group_ids`, which re-enters here."""
        mobile_group = self.env.ref(MOBILE_USER_GROUP, raise_if_not_found=False)
        if not mobile_group or not ({"group_ids", "mobile_user"} & set(vals)):
            return super().write(vals)
        was_mobile = {user.id for user in self if mobile_group in user.group_ids}
        res = super().write(vals)
        self.filtered(
            lambda user: user.id not in was_mobile and mobile_group in user.group_ids
        )._mobile_grant_time_off_group()
        return res

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
