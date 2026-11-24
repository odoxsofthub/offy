from odoo import _, api, fields, models
from odoo.exceptions import ValidationError


class MobileTermsCondition(models.Model):
    """Singleton Terms & Conditions document shown in the mobile app.
    Served by the mobile API only when ``is_published`` is set."""

    _name = "mobile.terms.condition"
    _description = "Mobile Terms & Conditions"
    _inherit = ["mail.thread"]

    name = fields.Char(
        string="Title",
        required=True,
        default="Terms & Conditions",
        translate=True,
        tracking=True,
    )
    body = fields.Html(
        string="Content",
        translate=True,
        sanitize=True,
        help="Rich-text terms & conditions shown in the mobile app.",
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
            record.display_name = record.name or _("Terms & Conditions")

    @api.model_create_multi
    def create(self, vals_list):
        if self.search_count([]) > 0:
            raise ValidationError(
                _("Only one terms & conditions record can exist.")
            )
        return super().create(vals_list)

    def unlink(self):
        raise ValidationError(_("You cannot delete the terms & conditions."))

    @api.model
    def get_terms(self):
        """Return the singleton terms & conditions, creating it if missing."""
        terms = self.search([], limit=1)
        if not terms:
            terms = self.create({})
        return terms
