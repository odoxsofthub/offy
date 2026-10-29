from odoo import fields, models


class ProductTemplate(models.Model):
    _inherit = "product.template"

    mobile_requires_receipt = fields.Boolean(
        string="Mobile: Requires Receipt",
        default=False,
        help="If enabled, the mobile app's expense category list flags this "
             "category as requiring a receipt attachment.",
    )
