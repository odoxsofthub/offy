"""Move the attendance geofence back from ``res.company`` to ``mobile.config``.
Post-migrate: new columns exist only after load; values come from the main company and the old columns are dropped."""

import logging

_logger = logging.getLogger(__name__)

GEOFENCE_COLUMNS = (
    "attendance_gps_required",
    "attendance_checkin_gps_required",
    "attendance_checkout_gps_required",
    "attendance_gps_boundary",
    "attendance_latitude",
    "attendance_longitude",
)


def _res_company_has_geofence(cr):
    cr.execute(
        """
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'res_company'
              AND column_name = 'attendance_latitude'
        )
        """
    )
    return cr.fetchone()[0]


def migrate(cr, version):
    if not version:
        return

    if not _res_company_has_geofence(cr):
        _logger.info(
            "res_company carries no geofence columns; nothing to move back.")
        return

    cr.execute(
        """
        SELECT id, %s FROM res_company ORDER BY id
        """ % ", ".join(GEOFENCE_COLUMNS)
    )
    rows = cr.fetchall()
    if not rows:
        _logger.info("No companies found; leaving mobile.config defaults.")
    else:
        # Warn before discarding anything a multi-company setup diverged on.
        if len(rows) > 1:
            distinct = {row[1:] for row in rows}
            if len(distinct) > 1:
                _logger.warning(
                    "%s companies have differing attendance geofences. Only the "
                    "main company's values are kept on mobile.config; re-enter "
                    "the others as work-location coordinates. Discarded: %s",
                    len(rows),
                    [dict(zip(GEOFENCE_COLUMNS, row[1:])) for row in rows[1:]],
                )

        (_company_id, required, checkin, checkout,
         boundary, latitude, longitude) = rows[0]

        cr.execute(
            """
            UPDATE mobile_config
            SET attendance_gps_required = %s,
                attendance_checkin_gps_required = %s,
                attendance_checkout_gps_required = %s,
                attendance_gps_boundary = %s,
                company_latitude = %s,
                company_longitude = %s
            """,
            (bool(required), bool(checkin), bool(checkout),
             boundary or 50, latitude or 0.0, longitude or 0.0),
        )
        _logger.info(
            "Restored the attendance geofence onto mobile.config "
            "(lat=%s, lng=%s, boundary=%s m, enabled=%s).",
            latitude, longitude, boundary, bool(required),
        )

    cr.execute(
        "ALTER TABLE res_company %s"
        % ", ".join("DROP COLUMN IF EXISTS %s" % c for c in GEOFENCE_COLUMNS)
    )
    _logger.info("Dropped the geofence columns from res_company.")
