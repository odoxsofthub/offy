"""Drop the unused App Versions fields from ``mobile.config``.
Odoo leaves columns of removed fields behind, so drop them and their tracking history explicitly."""

import logging

_logger = logging.getLogger(__name__)

REMOVED_FIELDS = ("force_update", "minimum_app_version", "latest_app_version")


def migrate(cr, version):
    if not version:
        return

    # Drop tracking history and ir.model.fields rows for the removed fields before dropping columns.
    cr.execute(
        """
        DELETE FROM mail_tracking_value
        WHERE field_id IN (
            SELECT id FROM ir_model_fields
            WHERE model = 'mobile.config' AND name IN %s
        )
        """,
        (REMOVED_FIELDS,),
    )
    _logger.info("Removed %s obsolete tracking value(s).", cr.rowcount)

    cr.execute(
        """
        DELETE FROM ir_model_fields
        WHERE model = 'mobile.config' AND name IN %s
        """,
        (REMOVED_FIELDS,),
    )
    _logger.info("Removed %s obsolete ir.model.fields row(s).", cr.rowcount)

    cr.execute(
        """
        ALTER TABLE mobile_config
            DROP COLUMN IF EXISTS force_update,
            DROP COLUMN IF EXISTS minimum_app_version,
            DROP COLUMN IF EXISTS latest_app_version
        """
    )
    _logger.info("Dropped the App Versions columns from mobile_config.")
