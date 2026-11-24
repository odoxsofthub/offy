from odoo import api, fields, models


class HrAttendance(models.Model):
    """Mobile GPS map links on attendance records.
    Shown only for sides captured by the mobile app with coordinates, never for manual records."""

    _inherit = "hr.attendance"

    mobile_check_in_location_enabled = fields.Boolean(
        string="Mobile Check In Location",
        default=False,
        readonly=True,
        copy=False,
        help="Set by the mobile API when the check-in location was captured "
             "from the mobile app.",
    )
    mobile_check_out_location_enabled = fields.Boolean(
        string="Mobile Check Out Location",
        default=False,
        readonly=True,
        copy=False,
        help="Set by the mobile API when the check-out location was captured "
             "from the mobile app.",
    )
    check_in_location_url = fields.Char(
        string="Check In Location",
        compute="_compute_mobile_location_urls",
    )
    check_out_location_url = fields.Char(
        string="Check Out Location",
        compute="_compute_mobile_location_urls",
    )

    @api.depends(
        "mobile_check_in_location_enabled", "mobile_check_out_location_enabled",
        "in_latitude", "in_longitude", "out_latitude", "out_longitude",
    )
    def _compute_mobile_location_urls(self):
        for rec in self:
            rec.check_in_location_url = (
                "https://maps.google.com?q=%s,%s"
                % (rec.in_latitude, rec.in_longitude)
                if rec.mobile_check_in_location_enabled
                and rec.in_latitude and rec.in_longitude
                else False
            )
            rec.check_out_location_url = (
                "https://maps.google.com?q=%s,%s"
                % (rec.out_latitude, rec.out_longitude)
                if rec.mobile_check_out_location_enabled
                and rec.out_latitude and rec.out_longitude
                else False
            )
