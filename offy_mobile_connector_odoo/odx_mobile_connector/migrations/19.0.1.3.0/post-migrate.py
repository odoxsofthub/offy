"""Move the attendance geofence from `mobile.config` to `res.company`, copying the old value to every company.
Post-migrate because the target columns are created at model load; the old columns are dropped at the end.
"""

import logging

_logger = logging.getLogger(__name__)

# Keep in sync with GPS_BOUNDARY_* in models/mobile_config.py.
GPS_BOUNDARY_MIN = 50
GPS_BOUNDARY_MAX = 5000


def migrate(cr, version):
    if not version:
        return

    cr.execute(
        """
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'mobile_config'
              AND column_name = 'company_latitude'
        ) AND EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'res_company'
              AND column_name = 'attendance_latitude'
        )
        """
    )
    # res_company only has the target columns if the code that ran was 1.3.x; a
    # direct jump to a later version keeps the geofence on mobile_config already.
    if not cr.fetchone()[0]:
        _logger.info("Attendance geofence already migrated; nothing to do.")
        return

    cr.execute(
        """
        SELECT attendance_gps_required,
               attendance_checkin_gps_required,
               attendance_checkout_gps_required,
               attendance_gps_boundary,
               company_latitude,
               company_longitude
        FROM mobile_config
        ORDER BY id
        LIMIT 1
        """
    )
    row = cr.fetchone()

    if row:
        (required, checkin, checkout, boundary, latitude, longitude) = row
        boundary = boundary or GPS_BOUNDARY_MIN

        # The new constraint caps the radius so a typo cannot silently disable the geofence; clamp it.
        if boundary > GPS_BOUNDARY_MAX:
            _logger.warning(
                "Attendance GPS boundary was %s m, above the new %s m maximum. "
                "Clamping to %s m. Employees between %s m and %s m from the "
                "attendance coordinates will no longer be able to check in -- "
                "review Settings > Employees > Attendances after this upgrade.",
                boundary, GPS_BOUNDARY_MAX, GPS_BOUNDARY_MAX,
                GPS_BOUNDARY_MAX, boundary,
            )
            boundary = GPS_BOUNDARY_MAX
        elif boundary < GPS_BOUNDARY_MIN:
            _logger.warning(
                "Attendance GPS boundary was %s m, below the %s m minimum. "
                "Raising to %s m.", boundary, GPS_BOUNDARY_MIN, GPS_BOUNDARY_MIN,
            )
            boundary = GPS_BOUNDARY_MIN

        cr.execute(
            """
            UPDATE res_company
            SET attendance_gps_required = %s,
                attendance_checkin_gps_required = %s,
                attendance_checkout_gps_required = %s,
                attendance_gps_boundary = %s,
                attendance_latitude = %s,
                attendance_longitude = %s
            """,
            (bool(required), bool(checkin), bool(checkout),
             boundary, latitude or 0.0, longitude or 0.0),
        )
        _logger.info(
            "Copied the attendance geofence to %s company/companies "
            "(lat=%s, lng=%s, boundary=%s m, enabled=%s).",
            cr.rowcount, latitude, longitude, boundary, bool(required),
        )

        if required and (checkin or checkout) and not (latitude and longitude):
            _logger.warning(
                "Attendance GPS validation is enabled but the migrated "
                "coordinates are empty. Check-in will fail with "
                "'company_location_missing' until they are set.",
            )
    else:
        _logger.info("No mobile.config row found; companies keep their defaults.")

    cr.execute(
        """
        ALTER TABLE mobile_config
            DROP COLUMN IF EXISTS attendance_gps_required,
            DROP COLUMN IF EXISTS attendance_checkin_gps_required,
            DROP COLUMN IF EXISTS attendance_checkout_gps_required,
            DROP COLUMN IF EXISTS attendance_gps_boundary,
            DROP COLUMN IF EXISTS company_latitude,
            DROP COLUMN IF EXISTS company_longitude
        """
    )
    _logger.info("Dropped the geofence columns from mobile_config.")
