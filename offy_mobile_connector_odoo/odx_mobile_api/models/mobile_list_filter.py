import json
import logging

from odoo import api, fields, models

_logger = logging.getLogger(__name__)


class MobileListFilter(models.Model):
    """The filters a mobile user has applied to one list: one row per (user, source, view).
    Selections live in one JSON document `{option_key: value}` so new filters need no migration.
    """

    _name = "mobile.list.filter"
    _description = "Mobile List Filter State"
    _order = "id desc"

    user_id = fields.Many2one(
        "res.users", required=True, index=True, ondelete="cascade"
    )
    source = fields.Char(required=True, index=True)
    # Per-list key; "" for single-list sources. Legacy "" rows are deliberately orphaned for time off.
    view = fields.Char(required=True, default="", index=True)
    state_json = fields.Text(default="{}")
    updated_at = fields.Datetime(default=fields.Datetime.now)

    # `models.Constraint`, not `_sql_constraints`: the list form is inert in Odoo 19 and creates nothing.
    _user_source_view_uniq = models.Constraint(
        "unique(user_id, source, view)",
        "A user has at most one filter state per list source and view.",
    )

    @api.model
    def _row_for(self, user, source, view=""):
        return self.sudo().search([
            ("user_id", "=", user.id),
            ("source", "=", source),
            ("view", "=", view or ""),
        ], limit=1)

    @api.model
    def get_state(self, user, source, view=""):
        """The active filter document for *user* on *source*; corrupt JSON is treated as no filters."""
        row = self._row_for(user, source, view)
        if not row or not row.state_json:
            return {}
        try:
            state = json.loads(row.state_json)
        except (TypeError, ValueError):
            _logger.warning(
                "Unreadable filter state for user %s source %s view %r;"
                " ignoring.", user.id, source, view)
            return {}
        return state if isinstance(state, dict) else {}

    @api.model
    def set_option(self, user, source, option, value, clears=(), view=""):
        """Store *value* for *option*, or delete it when None; `clears` drops other options in the same write.
        Used for mutual exclusivity (months vs date range); cleared options are deleted, never stored as null.
        """
        state = self.get_state(user, source, view)
        for other in clears:
            state.pop(other, None)
        if value is None:
            state.pop(option, None)
        else:
            state[option] = value

        row = self._row_for(user, source, view)
        values = {
            "state_json": json.dumps(state, sort_keys=True),
            "updated_at": fields.Datetime.now(),
        }
        if row:
            row.write(values)
        else:
            values.update({"user_id": user.id, "source": source,
                           "view": view or ""})
            self.sudo().create(values)
        return state
