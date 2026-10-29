from odoo import _, api, fields, models
from odoo.exceptions import ValidationError


class MobilePrivacyPolicy(models.Model):
    """Singleton Privacy Policy document (rich-text HTML) shown in the mobile app.
    Served by the API only when ``is_published`` is set."""

    _name = "mobile.privacy.policy"
    _description = "Mobile Privacy Policy"
    _inherit = ["mail.thread"]

    name = fields.Char(
        string="Title",
        required=True,
        default="Privacy Policy",
        translate=True,
        tracking=True,
    )
    body = fields.Html(
        string="Content",
        translate=True,
        sanitize=True,
        help="Rich-text privacy policy shown in the mobile app.",
    )
    is_published = fields.Boolean(
        string="Published",
        default=True,
        tracking=True,
        help="When enabled, the mobile app can fetch this document. "
             "Disable to hide it from the app without deleting it.",
    )

    def _compute_display_name(self):
        for record in self:
            record.display_name = record.name or _("Privacy Policy")

    @api.model_create_multi
    def create(self, vals_list):
        if self.search_count([]) > 0:
            raise ValidationError(_("Only one privacy policy record can exist."))
        return super().create(vals_list)

    def unlink(self):
        raise ValidationError(_("You cannot delete the privacy policy."))

    @api.model
    def get_privacy_policy(self):
        """Return the singleton privacy policy, creating it if missing."""
        policy = self.search([], limit=1)
        if not policy:
            policy = self.create({})
        return policy
