from odoo import models

from .hr_work_location import resolve_gps_override


class HrEmployee(models.Model):
    """Resolves which attendance geofence applies to an employee."""

    _inherit = "hr.employee"

    def _mobile_attendance_geofence(self):
        """Return the geofence policy dict for this employee: ``mobile.config`` overridden by the work location.
        Each site switch is tri-state (``global`` inherits); an empty recordset returns an all-off policy."""
        off = {
            "enabled": False,
            "checkin_required": False,
            "checkout_required": False,
            "latitude": 0.0,
            "longitude": 0.0,
            "boundary_meters": 0,
            "source": "config",
        }
        if not self:
            return off
        self.ensure_one()

        # Geofence values are configuration, not employee data, so reading them via sudo() leaks nothing.
        config = self.env["mobile.config"].sudo().search([], limit=1)
        if not config:
            return off

        enabled = config.attendance_gps_required
        checkin = config.attendance_checkin_gps_required
        checkout = config.attendance_checkout_gps_required
        latitude = config.company_latitude
        longitude = config.company_longitude
        boundary = config.attendance_gps_boundary
        source = "config"

        # work_location_id is delegated from hr.version via _inherits, hence the sudo() read.
        location = self.work_location_id.sudo()
        if location:
            enabled = resolve_gps_override(
                location.attendance_gps_required_mode, enabled)
            checkin = resolve_gps_override(
                location.attendance_checkin_gps_mode, checkin)
            checkout = resolve_gps_override(
                location.attendance_checkout_gps_mode, checkout)
            if location.attendance_latitude and location.attendance_longitude:
                latitude = location.attendance_latitude
                longitude = location.attendance_longitude
                # 0 means "inherit the global radius" -- see hr_work_location.py.
                boundary = location.attendance_gps_boundary or boundary
                source = "work_location"

        return {
            "enabled": enabled,
            "checkin_required": checkin,
            "checkout_required": checkout,
            "latitude": latitude,
            "longitude": longitude,
            "boundary_meters": boundary,
            "source": source,
        }
