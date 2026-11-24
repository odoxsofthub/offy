from odoo import _, api, fields, models
from odoo.exceptions import UserError, ValidationError


class MobileFeature(models.Model):
    """A discrete capability exposed in the mobile app; features shipped via XML data cannot be deleted."""

    _name = "mobile.feature"
    _description = "Mobile Feature"
    _inherit = ["mail.thread"]
    _order = "sequence, name"

    name = fields.Char(string="Name", required=True, translate=True, tracking=True)
    code = fields.Char(
        string="Code",
        required=True,
        tracking=True,
        help="Unique technical identifier used by the mobile application.",
    )
    description = fields.Text(string="Description", translate=True)
    sequence = fields.Integer(string="Sequence", default=10)
    active = fields.Boolean(string="Active", default=True, tracking=True)

    user_access_ids = fields.One2many(
        comodel_name="mobile.user.feature",
        inverse_name="feature_id",
        string="User Access",
        help="One row per Mobile User (managed automatically). Listed users get "
             "full access to this feature; remove a row to hide it from that user.",
    )
    access_user_ids = fields.Many2many(
        comodel_name="res.users",
        string="Configured Users",
        compute="_compute_access_user_ids",
        help="Users already listed in the access table; used to keep the add "
             "picker free of duplicates.",
    )
    is_default = fields.Boolean(
        string="Default Feature",
        compute="_compute_is_default",
        help="True for features shipped with the module. Their Name and Code "
             "are protected (read-only).",
    )
    log_notes_enabled = fields.Boolean(
        string="Log Notes Enabled",
        compute="_compute_log_notes_enabled",
    )
    show_chatter = fields.Boolean(
        string="Show Chatter Logs",
        compute="_compute_show_chatter",
    )



    @api.depends("user_access_ids.user_id")
    def _compute_access_user_ids(self):
        for feature in self:
            feature.access_user_ids = feature.user_access_ids.user_id

    @api.depends("code")
    def _compute_is_default(self):
        shipped = self._shipped_features()
        for feature in self:
            feature.is_default = feature in shipped

    def _compute_log_notes_enabled(self):
        log_notes_enabled = self.env["mobile.config"].get_config().log_notes_enabled
        for record in self:
            record.log_notes_enabled = log_notes_enabled

    def _compute_show_chatter(self):
        show_chatter = self.env["mobile.config"].get_config().show_chatter
        for record in self:
            record.show_chatter = show_chatter

    @api.model
    def _cleanup_global_profile_feature(self):
        """Remove the old Profile feature: profile is globally available."""
        profile = self.sudo().search([("code", "=", "profile")])
        if profile:
            profile.with_context(_force_unlink=True).unlink()

    def action_toggle_chatter(self):
        config = self.env["mobile.config"].get_config()
        config.write({"show_chatter": not config.show_chatter})




    _code_unique = models.Constraint(
        "UNIQUE(code)",
        "The feature code must be unique.",
    )

    @api.constrains("name")
    def _check_unique_name(self):
        """Disallow duplicate feature names (case-insensitive)."""
        for feature in self:
            if not feature.name:
                continue
            duplicate = self.search_count([
                ("id", "!=", feature.id),
                ("name", "=ilike", feature.name),
            ])
            if duplicate:
                raise ValidationError(
                    _("A feature named '%s' already exists.", feature.name)
                )

    @api.model_create_multi
    def create(self, vals_list):
        """Attach every Mobile User to each newly created feature."""
        features = super().create(vals_list)
        group = self.env.ref(
            "odx_mobile_connector.group_mobile_user", raise_if_not_found=False
        )
        if group:
            users = self.env["res.users"].sudo().search([("group_ids", "in", group.id)])
            if users:
                self.env["mobile.user.feature"].sudo().create([
                    {"user_id": u.id, "feature_id": f.id}
                    for f in features for u in users
                ])
        return features

    def _shipped_features(self):
        """Return the subset of `self` shipped with the module (those with an odx_mobile_connector external id)."""
        if not self:
            return self.browse()
        shipped = self.env["ir.model.data"].sudo().search([
            ("model", "=", "mobile.feature"),
            ("res_id", "in", self.ids),
            ("module", "=", "odx_mobile_connector"),
        ])
        return self.browse(set(shipped.mapped("res_id")))

    def unlink(self):
        """Prevent deletion of shipped features, unless `_force_unlink` is set by the uninstall/cleanup flow."""
        if not self.env.context.get("_force_unlink"):
            protected = self._shipped_features()
            if protected:
                raise UserError(
                    _(
                        "Default features %s cannot be deleted. "
                        "Instead, mark it as inactive to remove it from the mobile app.",
                        ", ".join(protected.mapped("name")),
                    )
                )
        return super().unlink()

    def write(self, vals):
        """Block edits to shipped features except `active` and `user_access_ids`.
        The install/upgrade flow (`install_mode` in context) still applies XML data updates.
        """
        if not self.env.context.get("install_mode") and not self.env.context.get("_force_unlink"):
            if set(vals.keys()) - {"active", "user_access_ids", "search_user_name", "show_chatter"}:
                protected = self._shipped_features()
                if protected:
                    raise UserError(
                        _(
                            "Default features %s cannot be edited. "
                            "Instead, mark it as inactive to remove it from the mobile app.",
                            ", ".join(protected.mapped("name")),
                        )
                    )
        # Field tracking (chatter) only when the activity log is enabled.
        if not self._log_notes_enabled():
            res = super(
                MobileFeature, self.with_context(tracking_disable=True)
            ).write(vals)
        else:
            res = super().write(vals)

        # Archiving or unarchiving a feature changes what every linked user may do; notify them.
        if "active" in vals:
            self.env["mobile.sync.service"].notify_access(
                self.mapped("user_access_ids.user_id"),
                reason="feature_activation_changed",
            )
        return res

    def _log_notes_enabled(self):
        """Master switch (mobile.config) for feature activity logging."""
        config = self.env["mobile.config"].sudo().search([], limit=1)
        return bool(config and config.log_notes_enabled)
