from odoo import fields, models


class MobileFaq(models.Model):
    """A single FAQ entry (heading + sub-heading) shown in the mobile app.
    Ordered by ``sequence`` and archived via ``active``; the API returns active entries only."""

    _name = "mobile.faq"
    _description = "Mobile FAQ"
    _order = "sequence, id"
    _rec_name = "heading"

    heading = fields.Char(
        string="Heading",
        required=True,
        translate=True,
        help="The question or title of the FAQ entry.",
    )
    sub_heading = fields.Text(
        string="Sub-heading",
        required=True,
        translate=True,
        help="The answer or supporting detail for the FAQ entry.",
    )
    sequence = fields.Integer(string="Sequence", default=10)
    active = fields.Boolean(string="Active", default=True)
