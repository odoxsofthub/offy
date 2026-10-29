import calendar as py_calendar
import logging
from datetime import date, timedelta

from odoo import fields
from odoo.exceptions import AccessError, UserError, ValidationError
from odoo.http import request

from . import main
from ..filter_sources import TimeoffFilterSource, group_by_timeline
from .main import API_KEY_SCOPE

_logger = logging.getLogger(__name__)

# hr.leave states → mobile-friendly stage names
STAGE_BY_STATE = {
    "confirm": "pending",
    "validate1": "pending",   # second-approval flows are still pending for the user
    "validate": "approved",
    "refuse": "rejected",
    "cancel": "cancelled",
}
STAGE_DISPLAY = {
    "pending": "Pending Approval",
    "approved": "Approved",
    "rejected": "Refused",
    "cancelled": "Cancelled",
}

CALENDAR_ABSENCE_STATES = ("confirm", "validate1", "validate")

# Kept complete on purpose: covers every state, even ones the domain filters out.
CALENDAR_STATUS_BY_STATE = {
    "confirm": "pending",
    "validate1": "pending_second_approval",
    "validate": "approved",
    "refuse": "refused",
    "cancel": "cancelled",
}
CALENDAR_STATUS_DISPLAY = {
    "pending": "Pending",
    "pending_second_approval": "Second Approval",
    "approved": "Approved",
    "refused": "Refused",
    "cancelled": "Cancelled",
}

# Odoo's standard 12-colour record palette (hr.leave.type.color is an integer index).
ODOO_COLOR_PALETTE = (
    "#FFFFFF", "#F06050", "#F4A460", "#F7CD1F", "#6CC1ED", "#814968",
    "#EB7E7F", "#2C8397", "#475577", "#D6145F", "#30C381", "#9365B8",
)


def _iso_date(d):
    return d.isoformat() if d else None


def _slug(name):
    return "_".join((name or "").lower().split())


def _color_hex(color_index):
    try:
        return ODOO_COLOR_PALETTE[color_index]
    except (IndexError, TypeError):
        return ODOO_COLOR_PALETTE[0]


def _format_number(value):
    """Render 2.0 as '2' and 2.5 as '2.5' for chip labels."""
    if value == int(value):
        return "%d" % int(value)
    return ("%.2f" % value).rstrip("0").rstrip(".")


def _parse_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


# Single shared implementation lives in main.py.
_parse_date = main.parse_date


def _date_span(start_date, end_date):
    if not start_date:
        return []
    end_date = end_date or start_date
    if end_date < start_date:
        end_date = start_date
    days = []
    current = start_date
    while current <= end_date:
        days.append(current)
        current += timedelta(days=1)
    return days


def _date_label(value):
    return "%s, %s %s" % (
        value.strftime("%A"),
        value.strftime("%B"),
        value.day,
    )


class MobileApiTimeoff(main.MobileApiAuth):
    """Time Off screen data: balances, upcoming leaves, leave history."""

    def _authenticate_timeoff(self, need_write=False):
        """Shared auth, time_off feature check and employee resolution; returns (user, error)."""
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

        if not self._mobile_feature_allowed(user, "time_off"):
            return None, self._json(success=False, code="time_off_access_denied",
                                    message="You do not have permission to %s time off."
                                            % ("request" if need_write else "view"),
                                    status=403)

        if not user.employee_id:
            return None, self._json(success=False, code="employee_not_linked",
                                    message="No employee is linked to this mobile user.",
                                    status=404)
        return user, None

    def _authenticate_timeoff_calendar(self):
        """Auth for read-only calendar APIs; same gate as time_off, employee_not_found wording."""
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

        if not self._mobile_feature_allowed(user, "time_off"):
            return None, self._json(success=False, code="time_off_access_denied",
                                    message="You do not have permission to view time off.",
                                    status=403)

        if not user.employee_id:
            return None, self._json(success=False, code="employee_not_found",
                                    message="No employee profile is linked to this mobile user.",
                                    status=404)
        return user, None

    def _leave_balances(self, employee):
        """Per-type balances via Odoo's own allocation helper, company-scoped and non-sudo.
        Same domain as `_requestable_types` so "can request" and "have left" never diverge."""
        leave_types = request.env["hr.leave.type"].search([
            "|",
            ("company_id", "=", False),
            ("company_id", "in", self._allowed_company_ids()),
        ])
        # Filtering the leave TYPES is not enough: the allocation rows must be company-filtered too.
        allocation_data = self._allocation_rows(leave_types, employee)
        balances = []
        for name, info, requires_allocation, type_id in allocation_data:
            if not requires_allocation or not info["max_leaves"]:
                continue
            balances.append({
                "id": type_id,
                "name": name,
                "remaining": info["virtual_remaining_leaves"],
                "total_allocated": info["max_leaves"],
                "taken": info["leaves_taken"],
                "pending": info["leaves_requested"],
                "unit": info["request_unit"],
            })
        return balances

    def _leave_payload(self, leave):
        stage = STAGE_BY_STATE.get(leave.state, leave.state)
        return {
            "id": leave.id,
            "name": leave.sudo().private_name or leave.holiday_status_id.name,
            "leave_type": {
                "id": leave.holiday_status_id.id,
                "name": leave.holiday_status_id.name,
            },
            "date_from": _iso_date(leave.request_date_from),
            "date_to": _iso_date(leave.request_date_to),
            "days": leave.number_of_days,
            "stage": stage,
            # Human-readable label for `stage` (e.g. "rejected" -> "Refused").
            "stage_display": STAGE_DISPLAY.get(stage, stage.title()),
        }

    def _calendar_leave_domain(self, employee, start_date, end_date):
        """Leaves marking a date, shared by month grid and day sheet so counts and items agree."""
        return [
            ("employee_id", "=", employee.id),
            ("state", "in", CALENDAR_ABSENCE_STATES),
            ("request_date_from", "<=", end_date),
            ("request_date_to", ">=", start_date),
        ]

    def _calendar_status(self, leave):
        status = CALENDAR_STATUS_BY_STATE.get(leave.state, leave.state)
        return status, CALENDAR_STATUS_DISPLAY.get(status, status.title())

    def _calendar_leave_type_code(self, leave_type):
        return _slug(leave_type.name)

    def _calendar_duration_display(self, duration):
        value = _format_number(duration or 0.0)
        return "%s %s" % (value, "Day" if value == "1" else "Days")

    def _calendar_leave_item(self, leave):
        leave_type = leave.holiday_status_id
        status, status_display = self._calendar_status(leave)
        duration_display = self._calendar_duration_display(leave.number_of_days)
        return {
            "id": leave.id,
            "title": leave.name or leave_type.name,
            "reason": leave.name or None,
            "leave_type": leave_type.name,
            "leave_type_code": self._calendar_leave_type_code(leave_type),
            "start_date": _iso_date(leave.request_date_from),
            "end_date": _iso_date(leave.request_date_to),
            "duration": leave.number_of_days,
            "duration_display": duration_display,
            "summary_display": "%s · %s" % (duration_display, leave_type.name),
            "status": status,
            "status_display": status_display,
            "color": _color_hex(leave_type.color),
        }

    @main.http.route("/api/mobile/v1/timeoff/calendar/month", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def timeoff_calendar_month(self, **kwargs):
        user, err = self._authenticate_timeoff_calendar()
        if err:
            return err

        raw_year = kwargs.get("year")
        raw_month = kwargs.get("month")
        if raw_year in (None, ""):
            return self._json(success=False, code="missing_year",
                              message="Year is required.", status=400)
        if raw_month in (None, ""):
            return self._json(success=False, code="missing_month",
                              message="Month is required.", status=400)

        year = _parse_int(raw_year)
        month = _parse_int(raw_month)
        if not year or year < 1900 or year > 2100:
            return self._json(success=False, code="invalid_year",
                              message="Year must be a valid four-digit year.",
                              status=400)
        if not month or month < 1 or month > 12:
            return self._json(success=False, code="invalid_month",
                              message="Month must be between 1 and 12.",
                              status=400)

        employee = user.employee_id
        first = date(year, month, 1)
        last = date(year, month, py_calendar.monthrange(year, month)[1])
        days = {
            first + timedelta(days=offset): {
                "leave_count": 0,
                "types": set(),
                "statuses": set(),
            }
            for offset in range((last - first).days + 1)
        }

        try:
            leaves = request.env["hr.leave"].search(
                self._calendar_leave_domain(employee, first, last),
                order="request_date_from asc, id asc",
            )
        except AccessError:
            return self._json(success=False, code="time_off_access_denied",
                              message="You do not have permission to view time off.",
                              status=403)
        except Exception:
            _logger.exception(
                "Mobile leave calendar month failed for uid=%s employee=%s "
                "range=%s..%s", user.id, employee.id, first, last)
            return self._json(success=False, code="timeoff_calendar_fetch_failed",
                              message="Leave calendar data could not be loaded.",
                              status=500)

        for leave in leaves:
            leave_type_code = self._calendar_leave_type_code(leave.holiday_status_id)
            status, _status_display = self._calendar_status(leave)
            for current in _date_span(leave.request_date_from, leave.request_date_to):
                if first <= current <= last:
                    days[current]["leave_count"] += 1
                    days[current]["types"].add(leave_type_code)
                    days[current]["statuses"].add(status)

        payload_days = []
        for current in sorted(days):
            info = days[current]
            payload_days.append({
                "date": current.isoformat(),
                "day": current.day,
                "leave_count": info["leave_count"],
                "types": sorted(info["types"]),
                "statuses": sorted(info["statuses"]),
            })

        return self._json(success=True,
                          message="Time off calendar month fetched successfully",
                          data={
                              "year": year,
                              "month": month,
                              "month_label": "%s %s" % (
                                  py_calendar.month_name[month], year),
                              "days": payload_days,
                          })

    @main.http.route("/api/mobile/v1/timeoff/calendar/day", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def timeoff_calendar_day(self, **kwargs):
        user, err = self._authenticate_timeoff_calendar()
        if err:
            return err

        raw_date = kwargs.get("date")
        if raw_date in (None, ""):
            return self._json(success=False, code="missing_date",
                              message="Date is required.", status=400)
        target_date = _parse_date(raw_date)
        if not target_date:
            return self._json(success=False, code="invalid_date",
                              message="Date must be in YYYY-MM-DD format.",
                              status=400)

        employee = user.employee_id
        try:
            leaves = request.env["hr.leave"].search(
                self._calendar_leave_domain(employee, target_date, target_date),
                order="request_date_from asc, id asc",
            )
        except AccessError:
            return self._json(success=False, code="time_off_access_denied",
                              message="You do not have permission to view time off.",
                              status=403)
        except Exception:
            _logger.exception(
                "Mobile leave calendar day failed for uid=%s employee=%s date=%s",
                user.id, employee.id, target_date)
            return self._json(success=False, code="timeoff_calendar_fetch_failed",
                              message="Leave calendar data could not be loaded.",
                              status=500)

        return self._json(success=True,
                          message="Time off calendar day fetched successfully",
                          data={
                              "date": target_date.isoformat(),
                              "date_label": _date_label(target_date),
                              "items": [self._calendar_leave_item(leave)
                                        for leave in leaves],
                          })

    def _timeoff_search_domain(self, user, view, kwargs):
        """`?search=` on either listing, ANDed with the stored filters; blank means no search."""
        term = (kwargs.get("search") or "").strip()
        if not term:
            return []
        return TimeoffFilterSource(user, view).search_domain(term)

    def _timeoff_filter(self, user, view):
        """`(source, state)` for one view's (`upcoming` or `history`) stored filters.
        Read once per request so the domain and the grouping cannot disagree."""
        source = TimeoffFilterSource(user, view)
        state = request.env["mobile.list.filter"].get_state(
            user, source.code, view)
        return source, state

    def _upcoming_domain(self, employee, today):
        # Includes "refuse" on purpose: a request the employee was watching here must not vanish silently.
        return [
            ("employee_id", "=", employee.id),
            ("request_date_to", ">=", today),
            ("state", "in", ("confirm", "validate1", "validate", "refuse")),
        ]

    def _history_domain(self, employee, today):
        """Past leaves of any status (`request_date_to < today`), the counterpart to `_upcoming_domain`.
        Status never moves a future leave here; a cancelled future one is in neither list."""
        return [
            ("employee_id", "=", employee.id),
            ("request_date_to", "<", today),
        ]

    @main.http.route("/api/mobile/v1/timeoff/history", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def timeoff_history(self, **kwargs):
        user, err = self._authenticate_timeoff()
        if err:
            return err
        employee = user.employee_id
        today = fields.Date.context_today(user)

        try:
            page = int(kwargs.get("page", 1))
            page_size = int(kwargs.get("page_size", 10))
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_pagination",
                              message="page and page_size must be integers.",
                              status=400)
        if page < 1 or page_size < 1:
            return self._json(success=False, code="invalid_pagination",
                              message="page and page_size must be >= 1.",
                              status=400)
        page_size = min(page_size, 50)

        domain = self._history_domain(employee, today)
        source, filter_state = self._timeoff_filter(user, "history")
        domain += source.domain_from_state(filter_state)
        domain += self._timeoff_search_domain(user, "history", kwargs)
        # Non-sudo: the caller reads their OWN leaves, which hr_holidays' record rules allow.
        leave_model = request.env["hr.leave"]
        total = leave_model.search_count(domain)
        leaves = leave_model.search(
            domain, order="request_date_from desc",
            limit=page_size, offset=(page - 1) * page_size,
        )

        total_pages = (total + page_size - 1) // page_size if total else 0
        return self._json(success=True, message="Leave history fetched successfully", data={
            # Month groups of THIS page in the list's own order; a date range collapses them (group_by_timeline).
            "leaves": group_by_timeline(
                leaves, [self._leave_payload(l) for l in leaves],
                "request_date_from", "leaves",
                source.range_bounds(filter_state)),
            "pagination": {
                "page": page,
                "page_size": page_size,
                "total": total,
                "total_pages": total_pages,
            },
        })

    @main.http.route("/api/mobile/v1/timeoff/upcoming", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def timeoff_upcoming(self, **kwargs):
        user, err = self._authenticate_timeoff()
        if err:
            return err
        employee = user.employee_id
        today = fields.Date.context_today(user)

        try:
            page = int(kwargs.get("page", 1))
            page_size = int(kwargs.get("page_size", 10))
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_pagination",
                              message="page and page_size must be integers.",
                              status=400)
        if page < 1 or page_size < 1:
            return self._json(success=False, code="invalid_pagination",
                              message="page and page_size must be >= 1.",
                              status=400)
        page_size = min(page_size, 50)

        domain = self._upcoming_domain(employee, today)
        source, filter_state = self._timeoff_filter(user, "upcoming")
        domain += source.domain_from_state(filter_state)
        domain += self._timeoff_search_domain(user, "upcoming", kwargs)
        # Non-sudo: see the history endpoint.
        leave_model = request.env["hr.leave"]
        total = leave_model.search_count(domain)
        leaves = leave_model.search(
            domain, order="request_date_from asc",
            limit=page_size, offset=(page - 1) * page_size,
        )

        total_pages = (total + page_size - 1) // page_size if total else 0
        return self._json(success=True, message="Upcoming leaves fetched successfully", data={
            # Month groups of THIS page in the list's own order; a date range collapses them (group_by_timeline).
            "leaves": group_by_timeline(
                leaves, [self._leave_payload(l) for l in leaves],
                "request_date_from", "leaves",
                source.range_bounds(filter_state)),
            "pagination": {
                "page": page,
                "page_size": page_size,
                "total": total,
                "total_pages": total_pages,
            },
        })

    @main.http.route("/api/mobile/v1/timeoff", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def timeoff(self, **kwargs):
        user, err = self._authenticate_timeoff()
        if err:
            return err
        employee = user.employee_id
        today = fields.Date.context_today(user)
        # Non-sudo: see the history endpoint.
        leave_model = request.env["hr.leave"]

        try:
            upcoming_limit = min(int(kwargs.get("upcoming_limit", 3)), 3)
            history_limit = min(int(kwargs.get("history_limit", 3)), 50)
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_pagination",
                              message="upcoming_limit and history_limit must be integers.",
                              status=400)
        if upcoming_limit < 1 or history_limit < 1:
            return self._json(success=False, code="invalid_pagination",
                              message="upcoming_limit and history_limit must be >= 1.",
                              status=400)

        # Upcoming: any non-cancelled request that hasn't ended yet
        upcoming_domain = self._upcoming_domain(employee, today)
        upcoming_total = leave_model.search_count(upcoming_domain)
        upcoming = leave_model.search(
            upcoming_domain, order="request_date_from asc", limit=upcoming_limit)

        # History: already ended -- ANY status. See `_history_domain`.
        history = leave_model.search(
            self._history_domain(employee, today),
            order="request_date_from desc", limit=history_limit)

        balances = self._leave_balances(employee)
        return self._json(success=True, message="Time off fetched successfully", data={
            "balances": balances,
            "total_remaining_leave": sum(b["remaining"] for b in balances),
            "upcoming": [self._leave_payload(l) for l in upcoming],
            "more_upcoming": upcoming_total > 3,
            "history": [self._leave_payload(l) for l in history],
        })

    def _selectable_leave_types(self, employee):
        """Leave types the employee may request, using the same domain as the Odoo form.
        has_valid_allocation depends on the contextual employee, so it is passed explicitly."""
        return request.env["hr.leave.type"].with_context(
            employee_id=employee.id,
        ).search([
            "|",
            ("requires_allocation", "=", False),
            ("has_valid_allocation", "=", True),
            "|",
            ("company_id", "=", False),
            ("company_id", "in", request.env.context.get(
                "allowed_company_ids", request.env.company.ids)),
        ], order="sequence, id")

    def _type_balance_info(self, leave_type, employee, target_date=None):
        """Balance for one type: (remaining, unit, max_leaves); remaining is None when unlimited."""
        if not leave_type.requires_allocation:
            return None, leave_type.request_unit, None
        # Company-filtered: this drives `remaining` and `can_apply`.
        data = self._allocation_rows(leave_type, employee, target_date)
        if not data:
            return 0.0, leave_type.request_unit, 0.0
        info = data[0][1]
        return (info["virtual_remaining_leaves"],
                info["request_unit"],
                info["max_leaves"])

    def _leave_type_payload(self, leave_type, employee):
        remaining, unit, _max_leaves = self._type_balance_info(leave_type, employee)
        is_unlimited = not leave_type.requires_allocation
        return {
            "id": leave_type.id,
            "name": leave_type.name,
            "code": _slug(leave_type.name),
            "remaining": remaining,
            "remaining_display": "Unlimited" if is_unlimited
                                 else _format_number(remaining),
            "unit": "hours" if unit == "hour" else "days",
            "is_unlimited": is_unlimited,
            "can_apply": is_unlimited or remaining > 0
                         or leave_type.allows_negative,
            "requires_allocation": leave_type.requires_allocation,
            "supports_negative": leave_type.allows_negative,
            "color": _color_hex(leave_type.color),
        }

    def _new_leave_duration(self, employee, leave_type, date_from, date_to):
        """(days, hours) of a would-be leave, computed on an in-memory `new()` hr.leave.
        Runs Odoo's own duration chain (calendar, holidays, unit) without create() side effects."""
        leave = request.env["hr.leave"].new({
            "employee_id": employee.id,
            "holiday_status_id": leave_type.id,
            "request_date_from": date_from,
            "request_date_to": date_to,
        })
        return leave.number_of_days, leave.number_of_hours

    def _parse_leave_request(self, payload, employee):
        """Validate the duration/create payload; returns (leave_type, date_from, date_to, error)."""
        def bad(code, message):
            return None, None, None, self._json(success=False, code=code,
                                                message=message, status=400)

        try:
            type_id = int(payload.get("time_off_type_id"))
        except (TypeError, ValueError):
            return bad("invalid_leave_type",
                       "time_off_type_id is required and must be an integer.")

        date_from = _parse_date(payload.get("start_date"))
        if not date_from:
            return bad("invalid_date",
                       "start_date is required and must be a valid date (YYYY-MM-DD).")
        date_to = _parse_date(payload.get("end_date"))
        if not date_to:
            return bad("invalid_date",
                       "end_date is required and must be a valid date (YYYY-MM-DD).")
        if date_to < date_from:
            return bad("invalid_date_range",
                       "End date cannot be before start date.")

        leave_type = self._selectable_leave_types(employee).filtered(
            lambda t: t.id == type_id)
        if not leave_type:
            return bad("invalid_leave_type",
                       "This leave type is not available to you.")
        return leave_type, date_from, date_to, None

    def _check_balance(self, leave_type, employee, date_from, days):
        """Insufficient-balance warning string, or None; mirrors Odoo's _check_validity rules."""
        if not leave_type.requires_allocation:
            return None
        remaining, unit, max_leaves = self._type_balance_info(
            leave_type, employee, target_date=date_from)
        if not max_leaves:
            return ("You do not have any allocation for this time off type.")
        allowed_excess = leave_type.max_allowed_negative if leave_type.allows_negative else 0
        if days > remaining + allowed_excess:
            return ("You do not have enough remaining leave for this request.")
        return None

    def _leave_request_context(self, user, employee, leave_type, date_from, date_to):
        """One-line diagnostic of the HR config driving ``hr.leave.create()``, for log records.
        Reads ``hr.employee.public`` without sudo and never raises."""
        parts = ["uid=%s" % user.id]
        try:
            parts.append("employee=%s" % employee.id)
            public = request.env["hr.employee.public"].browse(employee.id)
            parts.append("manager=%s" % (public.parent_id.id or None))
            parts.append("leave_approver=%s" % (public.leave_manager_id.id or None))
            parts.append("calendar=%s" % (public.resource_calendar_id.id or None))
            parts.append("employee_tz=%r" % (public.tz or None))
        except Exception:  # noqa: BLE001 - diagnostics must never raise
            parts.append("employee_details=unreadable")
        try:
            parts.append("type=%s(%s)" % (leave_type.id, leave_type.name))
            parts.append("validation=%s" % leave_type.leave_validation_type)
            parts.append("requires_allocation=%s" % leave_type.requires_allocation)
            parts.append("type_approvers=%s" % (leave_type.responsible_ids.ids or None))
        except Exception:  # noqa: BLE001
            parts.append("type_details=unreadable")
        parts.append("dates=%s..%s" % (_iso_date(date_from), _iso_date(date_to)))
        parts.append("user_tz=%r" % (user.tz or None))
        parts.append("companies=%s" % (request.env.context.get("allowed_company_ids"),))
        return " ".join(parts)

    @main.http.route("/api/mobile/v1/timeoff/types", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def timeoff_types(self, **kwargs):
        user, err = self._authenticate_timeoff()
        if err:
            return err
        employee = user.employee_id

        try:
            leave_types = self._selectable_leave_types(employee)
            data = [self._leave_type_payload(t, employee) for t in leave_types]
        except AccessError:
            return self._json(success=False, code="time_off_access_denied",
                              message="You do not have permission to view time off types.",
                              status=403)
        return self._json(success=True, message="Time off types fetched successfully",
                          data=data)

    @main.http.route("/api/mobile/v1/timeoff/duration", type="http", auth="none",
                     methods=["POST"], csrf=False, readonly=False)
    def timeoff_duration(self, **kwargs):
        user, err = self._authenticate_timeoff()
        if err:
            return err
        employee = user.employee_id
        payload = self._payload()

        leave_type, date_from, date_to, err = self._parse_leave_request(payload, employee)
        if err:
            return err

        try:
            days, _hours = self._new_leave_duration(
                employee, leave_type, date_from, date_to)
        except (AccessError, UserError, ValidationError):
            return self._json(success=False, code="duration_unavailable",
                              message="Unable to calculate the leave duration.",
                              status=400)

        # Always report in days, never hours, regardless of the leave type's request unit.
        duration = days
        warning = self._check_balance(leave_type, employee, date_from, days)
        return self._json(success=True, message="Duration calculated successfully", data={
            "duration": duration,
            "unit": "days",
            "display": "%s %s" % (_format_number(duration),
                                  "Day" + ("" if duration == 1 else "s")),
            "start_date": _iso_date(date_from),
            "end_date": _iso_date(date_to),
            "can_apply": warning is None and duration > 0,
            "warning": warning or (
                "The selected period contains no working days." if not duration else None),
        })

    @main.http.route("/api/mobile/v1/timeoff/request", type="http", auth="none",
                     methods=["POST"], csrf=False, readonly=False)
    def timeoff_request(self, **kwargs):
        user, err = self._authenticate_timeoff(need_write=True)
        if err:
            return err
        employee = user.employee_id
        payload = self._payload()

        leave_type, date_from, date_to, err = self._parse_leave_request(payload, employee)
        if err:
            return err

        reason = (payload.get("reason") or "").strip()

        # Pre-check duration + balance so the two dedicated error codes fire before create().
        try:
            days, _hours = self._new_leave_duration(
                employee, leave_type, date_from, date_to)
        except (AccessError, UserError, ValidationError):
            return self._json(success=False, code="duration_unavailable",
                              message="Unable to calculate the leave duration.",
                              status=400)
        if not days:
            return self._json(success=False, code="invalid_date_range",
                              message="The selected period contains no working days.",
                              status=400)
        warning = self._check_balance(leave_type, employee, date_from, days)
        if warning:
            return self._json(success=False, code="insufficient_balance",
                              message=warning, status=400)

        try:
            # Non-sudo on purpose: hr_holidays already grants base.group_user create on hr.leave.
            with request.env.cr.savepoint():
                leave = request.env["hr.leave"].create({
                    "employee_id": employee.id,
                    "holiday_status_id": leave_type.id,
                    "request_date_from": date_from,
                    "request_date_to": date_to,
                    "name": reason or False,
                })
        except (ValidationError, UserError) as exc:
            # These carry Odoo's own end-user-facing, translated text, so they are returned as-is.
            _logger.info(
                "Mobile leave request rejected by Odoo for %s: %s",
                self._leave_request_context(user, employee, leave_type,
                                            date_from, date_to),
                exc)
            return self._json(success=False, code="leave_request_invalid",
                              message=str(exc.args[0]) if exc.args else
                                      "This leave request is not valid.",
                              status=400)
        except AccessError:
            _logger.info(
                "Mobile leave request denied by access rules for %s",
                self._leave_request_context(user, employee, leave_type,
                                            date_from, date_to))
            return self._json(success=False, code="time_off_access_denied",
                              message="You do not have permission to request time off.",
                              status=403)
        except Exception:
            # Never leak internal Odoo errors/tracebacks to the mobile app; they are logged server-side.
            _logger.exception(
                "Mobile leave request failed unexpectedly for %s",
                self._leave_request_context(user, employee, leave_type,
                                            date_from, date_to))
            return self._json(success=False, code="leave_request_failed",
                              message="Unable to submit this leave request.",
                              status=400)

        status = STAGE_BY_STATE.get(leave.state, leave.state)
        return self._json(success=True, message="Leave request submitted successfully", data={
            "id": leave.id,
            "status": status,
            "status_display": STAGE_DISPLAY.get(status, status.title()),
            # Always days, never hours -- see timeoff_duration() above.
            "duration": leave.number_of_days,
            "unit": "days",
            "message": "Leave request submitted successfully.",
        })
