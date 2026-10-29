import pytz
from odoo.exceptions import AccessError
from odoo.http import request

from . import main
from .expense import STATUS_DISPLAY as EXPENSE_STATUS_DISPLAY
from .expense import STATUS_MAP as EXPENSE_STATUS_MAP
from .expense import _format_amount
from .home import _iso_utc
from .main import API_KEY_SCOPE
from .timeoff import STAGE_BY_STATE as LEAVE_STAGE_BY_STATE
from .timeoff import STAGE_DISPLAY as LEAVE_STAGE_DISPLAY
from .timeoff import _format_number

# Query "type" values <-> the mobile.feature code that gates that source.
FEATURE_BY_TYPE = {
    "leave": "time_off",
    "expense": "expense",
    "attendance": "attendance",
}

HOME_LIMIT = 3
DEFAULT_PAGE_LIMIT = 20
MAX_PAGE_LIMIT = 50
# Generous per-source cap: one employee's own activity is never large.
SOURCE_FETCH_LIMIT = 500

LEAVE_TERMINAL_TYPE = {
    "validate": "leave_approved",
    "refuse": "leave_refused",
    "cancel": "leave_cancelled",
}
LEAVE_TERMINAL_TITLE = {
    "leave_approved": "Leave approved",
    "leave_refused": "Leave refused",
    "leave_cancelled": "Leave cancelled",
}

EXPENSE_TERMINAL_TYPE = {
    "approved": "expense_approved",
    "posted": "expense_approved",
    "refused": "expense_refused",
    "in_payment": "expense_paid",
    "paid": "expense_paid",
}
EXPENSE_TERMINAL_TITLE = {
    "expense_approved": "Expense approved",
    "expense_refused": "Expense refused",
    "expense_paid": "Expense paid",
}


def _local_time_display(dt, tz_name):
    """Format a naive-UTC datetime as a short local time string, e.g. '09:45 AM'."""
    if not dt:
        return None
    tz = pytz.timezone(tz_name or "UTC")
    local = pytz.utc.localize(dt).astimezone(tz)
    return local.strftime("%I:%M %p").lstrip("0")


class MobileApiActivity(main.MobileApiAuth):
    """Recent Activity feed: the caller's leave, expense and attendance events, newest first.
    Add a source by writing one `_collect_*` method and one `FEATURE_BY_TYPE` entry."""

    def _authenticate_activity(self):
        """Returns (user, error_response); error_response is None on success."""
        token = self._bearer_token()
        if not token:
            return None, self._json(success=False, code="missing_access_token",
                                    message="Missing access token", status=401)
        uid = request.env["res.users.apikeys"].sudo()._check_credentials(
            scope=API_KEY_SCOPE, key=token
        )
        if not uid:
            return None, self._json(success=False, code="invalid_access_token",
                                    message="Invalid access token", status=401)

        request.update_env(user=uid)
        user = request.env.user
        if not user.active:
            return None, self._json(success=False, code="user_inactive",
                                    message="User is inactive", status=403)
        ok, message = self._check_mobile_access(user)
        if not ok:
            return None, self._json(success=False, code="mobile_access_denied",
                                    message=message, status=403)

        request.update_context(
            allowed_company_ids=self._get_company_context(uid))
        # Re-bound after the switch: res.users.employee_id depends on the company context.
        user = request.env.user

        if not user.employee_id:
            return None, self._json(success=False, code="employee_not_found",
                                    message="No employee profile is linked to this "
                                            "mobile user.", status=404)
        return user, None

    def _collect_leave_activities(self, employee, tz_name):
        items = []
        leaves = request.env["hr.leave"].search(
            [("employee_id", "=", employee.id)],
            order="write_date desc", limit=SOURCE_FETCH_LIMIT,
        )
        for leave in leaves:
            subtitle = "%s - %s Day%s" % (
                leave.holiday_status_id.name,
                _format_number(leave.number_of_days),
                "" if leave.number_of_days == 1 else "s",
            )
            stage = LEAVE_STAGE_BY_STATE.get(leave.state, leave.state)
            items.append({
                "id": "leave-%d" % leave.id,
                "source_model": "leave",
                "source_id": leave.id,
                "type": "leave_requested",
                "title": "Leave requested",
                "subtitle": subtitle,
                "status": stage,
                "status_display": LEAVE_STAGE_DISPLAY.get(stage, stage.title()),
                "occurred_at": leave.create_date,
                "icon": "calendar",
            })
            terminal_type = LEAVE_TERMINAL_TYPE.get(leave.state)
            if terminal_type:
                items.append({
                    "id": "leave-%d-%s" % (leave.id, leave.state),
                    "source_model": "leave",
                    "source_id": leave.id,
                    "type": terminal_type,
                    "title": LEAVE_TERMINAL_TITLE[terminal_type],
                    "subtitle": subtitle,
                    "status": stage,
                    "status_display": LEAVE_STAGE_DISPLAY.get(stage, stage.title()),
                    "occurred_at": leave.write_date,
                    "icon": "calendar",
                })
        return items

    def _collect_expense_activities(self, employee, tz_name):
        items = []
        currency = request.env.company.currency_id
        expenses = request.env["hr.expense"].search(
            [("employee_id", "=", employee.id)],
            order="write_date desc", limit=SOURCE_FETCH_LIMIT,
        )
        for expense in expenses:
            subtitle = "%s - %s" % (
                # Company-currency figure to match the company-currency symbol (see `expense_payload`).
                expense.name, _format_amount(expense.total_amount, currency)
            )
            status = EXPENSE_STATUS_MAP.get(expense.state, expense.state)
            items.append({
                "id": "expense-%d" % expense.id,
                "source_model": "expense",
                "source_id": expense.id,
                "type": "expense_requested",
                "title": "Expense requested",
                "subtitle": subtitle,
                "status": status,
                "status_display": EXPENSE_STATUS_DISPLAY.get(status, status.title()),
                "occurred_at": expense.create_date,
                "icon": "receipt",
            })
            terminal_type = EXPENSE_TERMINAL_TYPE.get(expense.state)
            if terminal_type:
                items.append({
                    "id": "expense-%d-%s" % (expense.id, expense.state),
                    "source_model": "expense",
                    "source_id": expense.id,
                    "type": terminal_type,
                    "title": EXPENSE_TERMINAL_TITLE[terminal_type],
                    "subtitle": subtitle,
                    "status": status,
                    "status_display": EXPENSE_STATUS_DISPLAY.get(status, status.title()),
                    "occurred_at": expense.write_date,
                    "icon": "receipt",
                })
        return items

    def _collect_attendance_activities(self, employee, tz_name):
        items = []
        attendances = request.env["hr.attendance"].search(
            [("employee_id", "=", employee.id)],
            order="write_date desc", limit=SOURCE_FETCH_LIMIT,
        )
        for attendance in attendances:
            if attendance.check_in:
                items.append({
                    "id": "attendance-%d-checkin" % attendance.id,
                    "source_model": "attendance",
                    "source_id": attendance.id,
                    "type": "checkin_created",
                    "title": "Checked in",
                    "subtitle": _local_time_display(attendance.check_in, tz_name),
                    "status": "done",
                    "status_display": "Done",
                    "occurred_at": attendance.check_in,
                    "icon": "login",
                })
            if attendance.check_out:
                items.append({
                    "id": "attendance-%d-checkout" % attendance.id,
                    "source_model": "attendance",
                    "source_id": attendance.id,
                    "type": "checkout_created",
                    "title": "Checked out",
                    "subtitle": _local_time_display(attendance.check_out, tz_name),
                    "status": "done",
                    "status_display": "Done",
                    "occurred_at": attendance.check_out,
                    "icon": "logout",
                })
        return items

    def _gather_items(self, user, employee, only_type):
        """Run every (or one) collector for features the user is allowed.
        A disabled or unlinked feature silently drops that source, never errors (deny-by-default)."""
        collectors = {
            "leave": self._collect_leave_activities,
            "expense": self._collect_expense_activities,
            "attendance": self._collect_attendance_activities,
        }
        tz_name = str(self._mobile_timezone(user))
        types = [only_type] if only_type else list(collectors)
        items = []
        for type_ in types:
            feature_code = FEATURE_BY_TYPE[type_]
            if not self._mobile_feature_allowed(user, feature_code):
                continue
            try:
                items.extend(collectors[type_](employee, tz_name))
            except AccessError:
                # e.g. a mobile user without base.group_user at all.
                continue
        return items

    @staticmethod
    def _sort_key(item):
        return (item["occurred_at"], item["source_model"], item["source_id"])

    @main.http.route("/api/mobile/v1/recent-activities", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def recent_activities(self, **kwargs):
        user, err = self._authenticate_activity()
        if err:
            return err
        employee = user.employee_id

        only_type = kwargs.get("type")
        if only_type and only_type not in FEATURE_BY_TYPE:
            return self._json(success=False, code="invalid_type",
                              message="type must be one of: leave, expense, attendance.",
                              status=400)

        date_from = date_to = None
        if kwargs.get("date_from"):
            date_from = main.parse_date(kwargs["date_from"])
            if not date_from:
                return self._json(success=False, code="invalid_date_range",
                                  message="date_from must be a valid date (YYYY-MM-DD).",
                                  status=400)
        if kwargs.get("date_to"):
            date_to = main.parse_date(kwargs["date_to"])
            if not date_to:
                return self._json(success=False, code="invalid_date_range",
                                  message="date_to must be a valid date (YYYY-MM-DD).",
                                  status=400)
        if date_from and date_to and date_from > date_to:
            return self._json(success=False, code="invalid_date_range",
                              message="date_from cannot be after date_to.", status=400)

        items = self._gather_items(user, employee, only_type)
        if date_from or date_to:
            def in_range(item):
                d = item["occurred_at"].date()
                if date_from and d < date_from:
                    return False
                if date_to and d > date_to:
                    return False
                return True
            items = [item for item in items if in_range(item)]

        items.sort(key=self._sort_key, reverse=True)

        home = str(kwargs.get("home", "")).lower() in ("1", "true", "yes")
        if home:
            payload = [self._activity_payload(item) for item in items[:HOME_LIMIT]]
            return self._json(success=True, message="Recent activities fetched successfully",
                              data={"items": payload, "home": True})

        try:
            page = int(kwargs.get("page", 1))
            limit = int(kwargs.get("limit", DEFAULT_PAGE_LIMIT))
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_page",
                              message="page and limit must be integers.", status=400)
        if page < 1:
            return self._json(success=False, code="invalid_page",
                              message="Page must be greater than zero.", status=400)
        if limit < 1:
            return self._json(success=False, code="invalid_limit",
                              message="Limit must be greater than zero.", status=400)
        limit = min(limit, MAX_PAGE_LIMIT)

        total = len(items)
        offset = (page - 1) * limit
        page_items = items[offset:offset + limit]

        return self._json(success=True, message="Recent activities fetched successfully", data={
            "items": [self._activity_payload(item) for item in page_items],
            "pagination": {
                "page": page,
                "limit": limit,
                "total": total,
                "has_next": offset + limit < total,
                "has_previous": page > 1,
            },
        })

    @staticmethod
    def _activity_payload(item):
        return {
            "id": item["id"],
            "source_model": item["source_model"],
            "source_id": item["source_id"],
            "type": item["type"],
            "title": item["title"],
            "subtitle": item["subtitle"],
            "status": item["status"],
            "status_display": item["status_display"],
            "occurred_at": _iso_utc(item["occurred_at"]),
            "icon": item["icon"],
        }
