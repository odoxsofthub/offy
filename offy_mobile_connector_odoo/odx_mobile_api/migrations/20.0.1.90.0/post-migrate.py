"""Odoo 20 upgrade: clear the saved time off "Leave Type" filter, and give mobile users the
time off Employee group.

`mobile.list.filter.state_json` stores `leave_type` as `hr.leave.type` ids. Odoo 20 merged
that model into `hr.work.entry.type`, and the merge is done by Odoo's upgrade service, which
leaves no v19-id -> v20-id table behind and keeps no `hr.leave.type` data in Odoo 20's
source. A guess by name could point a filter at the wrong type and hide real leaves, so
only that option is dropped. Month, date range and status selections are kept, and the
user re-picks the type from the values the list offers.
"""
import json
import logging

from odoo import SUPERUSER_ID, api

_logger = logging.getLogger(__name__)

SOURCE = "timeoff"
OPTION = "leave_type"


def migrate(cr, version):
    if not version:
        return
    _clear_leave_type_filters(cr)
    _grant_time_off_group(cr)


def _grant_time_off_group(cr):
    """Odoo 20 gives hr.leave / hr.work.entry.type access only to hr_holidays.group_hr_holidays_employee
    (v19 used base.group_user), and an upgraded v19 user may not hold it: every time off screen would
    then answer 403. Add it to active mobile users who lack it. Later grants go through res.users.write."""
    env = api.Environment(cr, SUPERUSER_ID, {})
    granted = env["res.users"]._mobile_grant_time_off_group_to_mobile_users()
    _logger.info(
        "odx_mobile_api 20.0.1.90.0: added the time off Employee group to %s mobile user(s)%s.",
        len(granted), (": %s" % granted.ids) if granted else "")


def _clear_leave_type_filters(cr):
    cr.execute(
        "SELECT id, state_json FROM mobile_list_filter WHERE source = %s",
        [SOURCE],
    )
    cleared = 0
    for row_id, raw in cr.fetchall():
        try:
            state = json.loads(raw or "{}")
        except (TypeError, ValueError):
            # get_state() already treats unreadable JSON as "no filters".
            continue
        if not isinstance(state, dict) or OPTION not in state:
            continue
        state.pop(OPTION)
        cr.execute(
            "UPDATE mobile_list_filter SET state_json = %s WHERE id = %s",
            [json.dumps(state, sort_keys=True), row_id],
        )
        cleared += 1
    _logger.info(
        "odx_mobile_api 20.0.1.90.0: cleared the saved leave type filter on %s"
        " time off filter row(s).", cleared)
