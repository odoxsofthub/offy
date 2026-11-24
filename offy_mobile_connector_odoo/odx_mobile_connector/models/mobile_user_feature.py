from odoo import _, api, fields, models


class MobileUserFeature(models.Model):
    """Link between a mobile user and a feature: a row grants full use, no row hides the feature (deny by default).
    Granting the Mobile User flag links every feature; revoking it removes the rows (see `res.users.write`).
    """

    _name = "mobile.user.feature"
    _description = "User Feature Access"
    _order = "user_id, feature_id"

    user_id = fields.Many2one(
        comodel_name="res.users",
        string="User",
        required=True,
        ondelete="cascade",
        index=True,
    )
    feature_id = fields.Many2one(
        comodel_name="mobile.feature",
        string="Feature",
        required=True,
        ondelete="cascade",
        index=True,
    )

    _user_feature_unique = models.Constraint(
        "UNIQUE(user_id, feature_id)",
        "A feature can only be configured once per user.",
    )

    def _access_log_enabled(self):
        """User-access logging requires both config switches to be on."""
        if self.env.context.get("_force_unlink"):
            return False
        config = self.env["mobile.config"].sudo().search([], limit=1)
        return bool(
            config and config.log_notes_enabled and config.log_user_access_changes
        )

    def _post_feature_log(self, body):
        """Post a note on each related feature's chatter (best effort)."""
        for access in self:
            feature = access.feature_id
            if feature and feature.exists():
                feature.message_post(body=body)

    def _notify_realtime(self):
        """Push the new permission set to any connected device of these users."""
        self.env["mobile.sync.service"].notify_access(
            self.mapped("user_id"), reason="feature_access_changed")

    @api.model_create_multi
    def create(self, vals_list):
        records = super().create(vals_list)
        if records._access_log_enabled():
            for access in records:
                access._post_feature_log(_(
                    "Mobile access granted to %(user)s",
                    user=access.user_id._get_html_link(),
                ))
        records._notify_realtime()
        return records

    def unlink(self):
        if self._access_log_enabled():
            for access in self:
                access._post_feature_log(_(
                    "Mobile access removed for %(user)s",
                    user=access.user_id._get_html_link(),
                ))
        # Capture the users before the rows go: after unlink() the rows can no longer be read.
        users = self.mapped("user_id")
        res = super().unlink()
        self.env["mobile.sync.service"].notify_access(
            users, reason="feature_access_revoked")
        return res
