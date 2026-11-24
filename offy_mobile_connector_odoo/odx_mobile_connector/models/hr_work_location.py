from odoo import _, api, fields, models
from odoo.exceptions import ValidationError

from .mobile_config import GPS_BOUNDARY_MAX, GPS_BOUNDARY_MIN

# Tri-state override used by every per-site GPS switch.
GPS_OVERRIDE_SELECTION = [
    ("global", "Use global setting"),
    ("yes", "Yes"),
    ("no", "No"),
]


def resolve_gps_override(mode, global_value):
    """Collapse a tri-state site override against the global switch."""
    if mode == "yes":
        return True
    if mode == "no":
        return False
    return global_value


class HrWorkLocation(models.Model):
    """Per-site attendance geofence overrides on ``hr.work.location``.
    Unset values inherit ``mobile.config``; set a home site's switches to ``no`` so it can check in."""

    _inherit = "hr.work.location"

    attendance_gps_required_mode = fields.Selection(
        selection=GPS_OVERRIDE_SELECTION,
        string="Attendance GPS Required",
        default="global",
        required=True,
        help="Master switch for employees at this site. 'Use global setting' "
             "follows OFFY Connector > Configuration > Attendance GPS.",
    )
    attendance_checkin_gps_mode = fields.Selection(
        selection=GPS_OVERRIDE_SELECTION,
        string="Checkin GPS Validation",
        default="global",
        required=True,
        help="Whether check-in is validated against the geofence at this site.",
    )
    attendance_checkout_gps_mode = fields.Selection(
        selection=GPS_OVERRIDE_SELECTION,
        string="Checkout GPS Validation",
        default="global",
        required=True,
        help="Whether check-out is validated against the geofence at this site.",
    )
    attendance_latitude = fields.Float(
        string="Attendance Latitude",
        digits=(10, 7),
        help="Geofence centre for this site. Leave empty to use the fallback "
             "coordinates from OFFY Connector > Configuration > Attendance GPS.",
    )
    attendance_longitude = fields.Float(
        string="Attendance Longitude",
        digits=(10, 7),
        help="Geofence centre for this site. Leave empty to use the fallback "
             "coordinates from OFFY Connector > Configuration > Attendance GPS.",
    )
    attendance_gps_boundary = fields.Integer(
        string="GPS Boundary (Meters)",
        help="Radius in meters accepted around this site. Leave at 0 to use "
             "the global boundary. Otherwise between %s and %s meters."
             % (GPS_BOUNDARY_MIN, GPS_BOUNDARY_MAX),
    )

    @api.constrains("attendance_gps_boundary")
    def _check_attendance_gps_boundary(self):
        for location in self:
            boundary = location.attendance_gps_boundary
            # 0 is the documented "inherit the global radius" value.
            if boundary and not (GPS_BOUNDARY_MIN <= boundary <= GPS_BOUNDARY_MAX):
                raise ValidationError(_(
                    "GPS Boundary for %(location)s must be 0 (use the global "
                    "boundary) or between %(low)s and %(high)s meters.",
                    location=location.display_name,
                    low=GPS_BOUNDARY_MIN, high=GPS_BOUNDARY_MAX))

    @api.constrains("attendance_latitude", "attendance_longitude")
    def _check_attendance_coordinates(self):
        """Reject a site with only one coordinate set.
        Otherwise it would silently fall back to the global fence."""
        for location in self:
            if bool(location.attendance_latitude) != bool(location.attendance_longitude):
                raise ValidationError(_(
                    "Set both Attendance Latitude and Attendance Longitude for "
                    "%(location)s, or leave both empty to use the fallback "
                    "coordinates.", location=location.display_name))

    @api.constrains(
        "attendance_gps_required_mode",
        "attendance_checkin_gps_mode",
        "attendance_checkout_gps_mode",
        "attendance_latitude",
        "attendance_longitude",
    )
    def _check_forced_validation_has_coordinates(self):
        """A site that forces validation must have a fence to validate against.
        Catches at configuration time what would otherwise block every check-in."""
        config = self.env["mobile.config"].sudo().search([], limit=1)
        fallback_set = bool(
            config and config.company_latitude and config.company_longitude)
        for location in self:
            forces_validation = (
                location.attendance_gps_required_mode == "yes"
                and "yes" in (location.attendance_checkin_gps_mode,
                              location.attendance_checkout_gps_mode)
            )
            own_coordinates = bool(
                location.attendance_latitude and location.attendance_longitude)
            if forces_validation and not own_coordinates and not fallback_set:
                raise ValidationError(_(
                    "%(location)s forces GPS validation but has no coordinates, "
                    "and no fallback coordinates are set under OFFY Connector "
                    "> Configuration > Attendance GPS. Employees at this site "
                    "would be unable to check in.",
                    location=location.display_name))
