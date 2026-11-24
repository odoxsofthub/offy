"""Drop can_read/can_write on mobile.user.feature: a link now means full access (deny-by-default).
Denial rows are deleted, read-only rows promoted, and missing rows created so users keep access."""

import logging

_logger = logging.getLogger(__name__)


def migrate(cr, version):
    if not version:
        return

    cr.execute(
        """
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'mobile_user_feature'
              AND column_name = 'can_read'
        )
        """
    )
    if not cr.fetchone()[0]:
        _logger.info("mobile_user_feature.can_read already removed; skipping.")
        return

    cr.execute("DELETE FROM mobile_user_feature WHERE can_read IS NOT TRUE")
    _logger.info("Removed %s denied mobile feature access row(s).", cr.rowcount)

    # Give every existing group_mobile_user an explicit access link so nobody loses a feature.
    cr.execute(
        """
        INSERT INTO mobile_user_feature (user_id, feature_id)
        SELECT gu.uid, f.id
        FROM res_groups_users_rel gu
        CROSS JOIN mobile_feature f
        JOIN ir_model_data imd
          ON imd.module = 'odx_mobile_connector'
         AND imd.name = 'group_mobile_user'
         AND imd.model = 'res.groups'
         AND imd.res_id = gu.gid
        ON CONFLICT (user_id, feature_id) DO NOTHING
        """
    )
    _logger.info("Backfilled %s implicit mobile feature access row(s).", cr.rowcount)

    cr.execute(
        """
        ALTER TABLE mobile_user_feature
            DROP COLUMN IF EXISTS can_read,
            DROP COLUMN IF EXISTS can_write
        """
    )
    _logger.info("Dropped mobile_user_feature.can_read / can_write.")
