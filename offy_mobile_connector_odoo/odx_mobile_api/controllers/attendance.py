import logging
import math
from calendar import monthrange
from collections import Counter, OrderedDict
from datetime import datetime, time, timedelta
from decimal import ROUND_HALF_UP, Decimal

import pytz
from psycopg2 import IntegrityError, OperationalError

from odoo.exceptions import (
    AccessError, ConcurrencyError, UserError, ValidationError,
)
from odoo.http import request

from . import main
from .home import _iso_utc
from .main import API_KEY_SCOPE

_logger = logging.getLogger(__name__)

# How recently the same action must have been recorded for a repeat request to
# be answered as a replay (200) instead of a 409. See `_replayed_action`.
ACTION_REPLAY_WINDOW = timedelta(minutes=5)


class _AttendanceNotRecorded(Exception):
    """Raised when `_attendance_action_change` returns no record, so the savepoint unwinds the write."""


DEFAULT_LOG_LIMIT = 20
MAX_LOG_LIMIT = 50


def _haversine_meters(lat1, lon1, lat2, lon2):
    """Great-circle distance between two points, in meters."""
    radius = 6371000.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = (math.sin(dphi / 2) ** 2
         + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2)
    return 2 * radius * math.asin(math.sqrt(a))


def _parse_positive_int(value, default, max_value=None):
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        parsed = default
    parsed = max(parsed, 1)
    if max_value:
        parsed = min(parsed, max_value)
    return parsed


def _local_date_bounds(day, tz):
    start = tz.localize(datetime.combine(day, time.min))
    end = tz.localize(datetime.combine(day, time.max))
    return (
        start.astimezone(pytz.utc).replace(tzinfo=None),
        end.astimezone(pytz.utc).replace(tzinfo=None),
    )


# A work day is one calendar day in the employee's timezone, keyed by check-in.
# A session crossing midnight is split across two dates, like Odoo's own reporting.
def _work_day(dt_utc, tz):
    """The calendar day *dt_utc* falls on in *tz*, as a `date`, or None."""
    local = _local_time(dt_utc, tz)
    if not local:
        return None
    return local.date()


def _work_day_bounds(day, tz):
    """Naive-UTC half-open ``[start, end)`` for one calendar day, so midnight never lands in two days.
    No `is_dst` on `tz.localize`, so a DST changeover resolves instead of raising."""
    start_local = tz.localize(datetime.combine(day, time.min))
    end_local = tz.localize(datetime.combine(day + timedelta(days=1), time.min))
    return (
        start_local.astimezone(pytz.utc).replace(tzinfo=None),
        end_local.astimezone(pytz.utc).replace(tzinfo=None),
    )


def work_day_bounds(day, tz):
    """Public alias of `_work_day_bounds` for cross-controller use."""
    return _work_day_bounds(day, tz)


def work_day(dt_utc, tz):
    """Public alias of `_work_day` for cross-controller use."""
    return _work_day(dt_utc, tz)


# Optional Enterprise Planning (planning.slot): not a manifest dependency; read as the user, no sudo.
PLANNING_SLOT_MODEL = "planning.slot"
PLANNING_EARLY_CHECKIN = timedelta(hours=2)
# How far beyond a month's window to look for shifts that straddle its edges.
PLANNING_LOOKAROUND = timedelta(days=2)


def _break_hours_in_shift(start_utc, end_utc, breaks):
    """Hours of the schedule's breaks inside a shift (every local day it touches).
    *breaks* is `_schedule_breaks()`; ``default`` windows apply on undefined days."""
    if not breaks or not (breaks["by_weekday"] or breaks["default"]):
        return 0.0
    tz = breaks["tz"]
    start = pytz.utc.localize(start_utc)
    end = pytz.utc.localize(end_utc)
    day = start.astimezone(tz).date()
    last_day = end.astimezone(tz).date()
    seconds = 0.0
    while day <= last_day:
        windows = breaks["by_weekday"].get(day.weekday(), breaks["default"])
        midnight = datetime.combine(day, time.min)
        for hour_from, hour_to in windows:
            lo = max(start, tz.localize(midnight + timedelta(hours=hour_from)))
            hi = min(end, tz.localize(midnight + timedelta(hours=hour_to)))
            if hi > lo:
                seconds += (hi - lo).total_seconds()
        day += timedelta(days=1)
    return seconds / 3600.0


def _shift_hours(shift, breaks=None):
    """A planned shift's target in hours: its Allocated Time when above zero.
    A 0h allocation at a non-zero % (no schedule overlap) uses length minus breaks; 0% means 0h."""
    allocated = shift.get("allocated_hours") or 0.0
    if allocated > 0:
        return float(allocated)
    percentage = shift.get("allocated_percentage")
    if percentage is None or percentage is False:
        percentage = 100.0
    if not percentage:
        return 0.0
    length = max(
        (shift["end_datetime"] - shift["start_datetime"]).total_seconds() / 3600.0,
        0.0)
    if breaks is not None:
        length = max(length - _break_hours_in_shift(
            shift["start_datetime"], shift["end_datetime"], breaks), 0.0)
    return length * float(percentage) / 100.0


def _shift_for_check_in(check_in, shifts):
    """The shift *check_in* belongs to, or None; inside a shift beats the next shift's early window."""
    if not check_in:
        return None
    for shift in shifts:
        if shift["start_datetime"] <= check_in < shift["end_datetime"]:
            return shift
    for shift in shifts:
        if shift["start_datetime"] - PLANNING_EARLY_CHECKIN <= check_in < shift["start_datetime"]:
            return shift
    return None


def _shift_day(shift, tz):
    """The day a shift is filed under: the local calendar date it starts."""
    local = _local_time(shift["start_datetime"], tz)
    return local.date() if local else None


# Every `targetReason` code needs a message here; `{}` slots take the leave type / holiday name.
TARGET_REASON_MESSAGES = {
    "time_off": "On leave ({})",
    "time_off_unnamed": "On leave",
    "public_holiday": "Public holiday ({})",
    "non_working_day": "Not a working day in your schedule",
    "no_schedule": "No working schedule assigned",
}


def _completion_percentage(worked_hours, target_hours):
    """`worked / target * 100` to one decimal (half-up), or None without a target.
    Not capped at 100: overtime is information, clamping is the client's job."""
    if not target_hours:
        return None
    value = Decimal(str((worked_hours or 0.0) / target_hours * 100))
    return float(value.quantize(Decimal("0.1"), rounding=ROUND_HALF_UP))


def _work_day_label(day):
    """"March 10, 2026" for a work day; fallback for a grouped row with no check-in time."""
    return day.strftime("%B %-d, %Y") if day else None


def _local_time(dt, tz):
    if not dt:
        return None
    return pytz.utc.localize(dt).astimezone(tz)


def _time_display(dt, tz):
    local = _local_time(dt, tz)
    return local.strftime("%I:%M %p").lstrip("0") if local else None


def _date_range_display(start_local, end_local):
    """"June 25, 2026" for one local day, or a compact range when check-in and check-out dates differ.
    Both arguments are timezone-localized; *end_local* is None for an open session."""
    if not start_local:
        return None
    if not end_local or start_local.date() == end_local.date():
        return start_local.strftime("%B %-d, %Y")
    if start_local.year != end_local.year:
        return "%s-%s" % (start_local.strftime("%B %-d, %Y"),
                          end_local.strftime("%B %-d, %Y"))
    if start_local.month != end_local.month:
        return "%s %-d-%s, %s" % (start_local.strftime("%B"), start_local.day,
                                  end_local.strftime("%B %-d"), start_local.year)
    return "%s %s-%s, %s" % (start_local.strftime("%B"), start_local.day,
                             end_local.day, start_local.year)


def _duration_display(hours):
    if hours is None:
        return None
    minutes = int(round(float(hours) * 60))
    return "%02dh %02dm" % (minutes // 60, minutes % 60)


def _duration_hours(check_in, check_out):
    """Elapsed hours between two naive-UTC datetimes, or None.
    Not `worked_hours`, which deducts the calendar's lunch break and would change the API's figure."""
    if not check_in or not check_out:
        return None
    seconds = (check_out - check_in).total_seconds()
    if seconds < 0:
        return None
    return seconds / 3600.0


def _attendance_duration_hours(attendance):
    return _duration_hours(attendance.check_in, attendance.check_out)


class MobileApiAttendance(main.MobileApiAuth):
    """Mobile check-in / check-out with optional per-action GPS validation.
    Fence: ``hr.employee._mobile_attendance_geofence``; coordinates are stored even when optional."""

    def _error(self, code, message, status=400):
        return self._json(success=False, code=code, message=message,
                          status=status)

    def _authenticate_attendance(self):
        """Authenticate the caller and confirm the attendance feature is allowed for them."""
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
            return None, self._error("employee_not_linked",
                                     "No employee is linked to this mobile user.",
                                     status=404)

        if not self._mobile_feature_allowed(user, "attendance"):
            return None, self._error("attendance_access_denied",
                                     "You do not have permission to access attendance.",
                                     status=403)
        return user, None

    def _attendance_period(self, args, tz):
        month = args.get("month")
        year = args.get("year")
        if month is None and year is None:
            return None, None, None
        elif month is None or year is None:
            return None, None, self._error(
                "invalid_period", "month and year must be provided together.")

        try:
            month = int(month)
            year = int(year)
        except (TypeError, ValueError):
            return None, None, self._error(
                "invalid_period", "month and year must be valid numbers.")
        if month < 1 or month > 12:
            return None, None, self._error(
                "invalid_period", "month must be between 1 and 12.")
        try:
            last_day = monthrange(year, month)[1]
            start = datetime(year, month, 1).date()
            end = datetime(year, month, last_day).date()
        except ValueError:
            return None, None, self._error(
                "invalid_period", "year must be a valid calendar year.")
        return start, end, None

    def _shift_status(self, attendance, tz):
        """Late vs On-Time for ONE record, judged against its check-in day."""
        return self._shift_status_against(
            attendance.check_in, None, attendance.employee_id, tz)

    def _shift_status_for_day(self, first_check_in, work_day, tz):
        """Late vs On-Time for a grouped day, using the work day's weekday, not the check-in's."""
        return self._shift_status_against(
            first_check_in, work_day, request.env.user.employee_id, tz)

    @staticmethod
    def _shift_status_for_shifts(first_check_in, shifts):
        """Late vs On-Time against the day's earliest planned shift start (both naive UTC)."""
        if not first_check_in or not shifts:
            return None
        start = min(shift["start_datetime"] for shift in shifts)
        return "Late" if first_check_in > start else "On-Time"

    def _shift_status_against(self, check_in_utc, work_day, employee, tz):
        check_in = _local_time(check_in_utc, tz)
        if not check_in:
            return None
        calendar = employee.resource_calendar_id
        if not calendar:
            return None
        weekday = str((work_day or check_in).weekday())
        day_slots = calendar.attendance_ids.filtered(lambda slot: slot.dayofweek == weekday)
        slots = day_slots
        if "day_period" in calendar.attendance_ids._fields:
            slots = day_slots.filtered(lambda slot: slot.day_period != "afternoon")
        if not slots:
            slots = day_slots
        if not slots:
            return None
        start_hour = min(slots.mapped("hour_from"))
        actual_hour = check_in.hour + check_in.minute / 60.0 + check_in.second / 3600.0
        return "Late" if actual_hour > start_hour else "On-Time"

    def _log_payload(self, attendance, tz):
        check_in_display = _time_display(attendance.check_in, tz)
        check_out_display = _time_display(attendance.check_out, tz)
        if attendance.check_out:
            status = "completed"
            time_info = "%s - %s" % (check_in_display, check_out_display)
            shift_duration = _duration_display(_attendance_duration_hours(attendance))
        elif attendance.check_in:
            status = "active"
            time_info = "%s - Present" % check_in_display
            shift_duration = None
        else:
            status = "none"
            time_info = None
            shift_duration = None

        check_in_local = _local_time(attendance.check_in or attendance.create_date, tz)
        check_out_local = _local_time(attendance.check_out, tz)
        return {
            "date": _date_range_display(check_in_local, check_out_local),
            "time_info": time_info,
            "status": status,
            "shift_duration": shift_duration,
            "shift_status": self._shift_status(attendance, tz) if status == "completed" else None,
        }

    def _group_rows_by_work_day(self, rows, tz, shifts=None):
        """Rows -> ``OrderedDict{work_day: [row, ...]}``, days newest first, sessions oldest first.
        Rows inside a published shift go under that shift's day; rows without `check_in` are dropped."""
        buckets = {}
        for row in rows:
            shift = _shift_for_check_in(row.get("check_in"), shifts or [])
            day = (_shift_day(shift, tz) if shift
                   else _work_day(row.get("check_in"), tz))
            if not day:
                continue
            buckets.setdefault(day, []).append(row)
        ordered = OrderedDict()
        for day in sorted(buckets, reverse=True):
            ordered[day] = sorted(buckets[day], key=lambda r: r["check_in"])
        return ordered

    def _session_events(self, rows, tz):
        """A day's sessions as the flat event list the app's timeline renders."""
        events = []
        for row in rows:
            events.append({
                "type": "check_in",
                "time": _time_display(row.get("check_in"), tz),
                "location": row.get("in_location") or None,
                "id": row.get("id"),
                "at": _iso_utc(row.get("check_in")),
            })
            if row.get("check_out"):
                events.append({
                    "type": "check_out",
                    "time": _time_display(row.get("check_out"), tz),
                    "location": row.get("out_location") or None,
                    "id": row.get("id"),
                    "at": _iso_utc(row.get("check_out")),
                })
        return events

    def _planning_installed(self):
        """Whether the Enterprise Planning app is installed in this database."""
        return PLANNING_SLOT_MODEL in request.env

    def _published_shifts(self, employee, start_utc, end_utc):
        """Published shifts overlapping ``[start_utc, end_utc)`` (naive UTC), sorted by start.
        ``[]`` when Planning is missing or unreadable, so the log never fails because of Planning."""
        if not employee or not self._planning_installed():
            return []
        try:
            shifts = request.env[PLANNING_SLOT_MODEL].search_read([
                ("employee_id", "=", employee.id),
                ("state", "=", "published"),
                ("start_datetime", "<", end_utc),
                ("end_datetime", ">", start_utc),
            ], ["start_datetime", "end_datetime", "allocated_hours",
                "allocated_percentage", "role_id"],
                order="start_datetime, id")
        except AccessError:
            _logger.info(
                "Planned shifts of employee %s are not readable by uid %s; "
                "using the default attendance grouping.",
                employee.id, request.env.uid)
            return []
        return [shift for shift in shifts
                if shift.get("start_datetime") and shift.get("end_datetime")
                and shift["end_datetime"] > shift["start_datetime"]]

    @staticmethod
    def _schedule_breaks(employee):
        """Schedule ``lunch`` windows by weekday; ``default`` (most common) covers other days.
        None for a flexible-hours schedule (no fixed breaks)."""
        calendar = employee.resource_calendar_id
        if calendar and calendar.flexible_hours:
            return None
        tz_name = (calendar and calendar.tz) or employee.tz or "UTC"
        try:
            tz = pytz.timezone(tz_name)
        except pytz.UnknownTimeZoneError:
            tz = pytz.utc
        by_weekday = {}
        if calendar:
            for line in calendar.attendance_ids:
                if line.day_period != "lunch" or (
                        "display_type" in line._fields and line.display_type):
                    continue
                window = (float(line.hour_from), float(line.hour_to))
                windows = by_weekday.setdefault(int(line.dayofweek), [])
                if window not in windows:
                    windows.append(window)
        counts = Counter(w for windows in by_weekday.values() for w in windows)
        default = [counts.most_common(1)[0][0]] if counts else []
        return {"tz": tz, "by_weekday": by_weekday, "default": default}

    @staticmethod
    def _shifts_by_day(shifts, tz):
        """`{day: [shift, ...]}`, each shift under `_shift_day`."""
        by_day = {}
        for shift in shifts:
            day = _shift_day(shift, tz)
            if day:
                by_day.setdefault(day, []).append(shift)
        return by_day

    @staticmethod
    def _planned_shift_payload(shift, tz):
        """One entry of a row's `plannedShifts`."""
        start_local = _local_time(shift["start_datetime"], tz)
        end_local = _local_time(shift["end_datetime"], tz)
        role = shift.get("role_id")
        return {
            "date": _date_range_display(start_local, end_local),
            "time_info": "%s - %s" % (_time_display(shift["start_datetime"], tz),
                                      _time_display(shift["end_datetime"], tz)),
            "start": _iso_utc(shift["start_datetime"]),
            "end": _iso_utc(shift["end_datetime"]),
            "duration": _duration_display(
                shift["_target_hours"] if "_target_hours" in shift
                else _shift_hours(shift)),
            "role": role[1] if role else None,
        }

    def _expected_hours_by_work_day(self, employee, days, tz):
        """`{day: expected hours}` via `_get_expected_attendances()` (versions, breaks, time off).
        One call per page; no schedule means no target (Odoo would report 24h)."""
        if not days or not employee.resource_calendar_id:
            # No schedule: `_targets_by_work_day` reports `no_schedule`.
            return {}
        windows = {}
        for day in days:
            start, end = _work_day_bounds(day, tz)
            windows[day] = (pytz.utc.localize(start), pytz.utc.localize(end))
        span_start = min(w[0] for w in windows.values())
        span_end = max(w[1] for w in windows.values())
        try:
            intervals = list(employee._get_expected_attendances(span_start, span_end))
        except Exception:
            # A schedule the calendar engine cannot evaluate must not take the attendance log down.
            _logger.exception(
                "Could not compute expected hours for employee %s.", employee.id)
            return {}
        return self._hours_per_window(intervals, windows)

    @staticmethod
    def _hours_per_window(intervals, windows):
        """`{day: hours}` -- how much of *intervals* falls in each window."""
        hours = {}
        for day, (window_start, window_end) in windows.items():
            seconds = 0.0
            for interval in intervals:
                lo = max(interval[0], window_start)
                hi = min(interval[1], window_end)
                if hi > lo:
                    seconds += (hi - lo).total_seconds()
            hours[day] = seconds / 3600.0
        return hours

    def _targets_by_work_day(self, employee, days, tz):
        """`{work day: (hours, reason, message)}`; reason: None, no_schedule, time_off or non_working_day.
        A day whose target could not be computed is omitted so "unknown" never reads as zero."""
        if not days:
            return {}
        if not employee.resource_calendar_id:
            return {day: (0.0, "no_schedule",
                          TARGET_REASON_MESSAGES["no_schedule"])
                    for day in days}
        if employee.resource_calendar_id.flexible_hours:
            return self._flexible_targets_by_work_day(employee, days, tz)

        expected = self._expected_hours_by_work_day(employee, days, tz)
        if not expected:
            return {}   # the calculation failed; it has already been logged

        zero_days = [day for day in days if not expected.get(day)]
        planned = {}
        leave_names = {}      # day -> [leave type names]
        holiday_names = {}    # day -> [public holiday names]
        if zero_days:
            windows = {}
            for day in zero_days:
                start, end = _work_day_bounds(day, tz)
                windows[day] = (pytz.utc.localize(start), pytz.utc.localize(end))
            try:
                employee_tz = pytz.timezone(employee.tz) if employee.tz else tz
                plan = employee.resource_calendar_id._attendance_intervals_batch(
                    min(w[0] for w in windows.values()),
                    max(w[1] for w in windows.values()),
                    resources=employee.resource_id, tz=employee_tz,
                )[employee.resource_id.id]
                planned = self._hours_per_window(list(plan), windows)
            except Exception:
                _logger.exception(
                    "Could not read the plain schedule for employee %s.",
                    employee.id)
            # The employee's OWN approved leave, by the calendar dates it covers.
            leaves = request.env["hr.leave"].search([
                ("employee_id", "=", employee.id),
                ("state", "=", "validate"),
                ("request_date_from", "<=", max(zero_days)),
                ("request_date_to", ">=", min(zero_days)),
            ])
            for leave in leaves:
                name = leave.holiday_status_id.name
                day = leave.request_date_from
                while day <= leave.request_date_to:
                    names = leave_names.setdefault(day, [])
                    if name and name not in names:
                        names.append(name)
                    day += timedelta(days=1)
            holiday_names = self._holiday_names_by_day(
                employee, windows, zero_days)

        targets = {}
        for day in days:
            hours = expected.get(day) or 0.0
            if hours:
                targets[day] = (hours, None, None)
            elif planned.get(day) and day in leave_names:
                names = ", ".join(leave_names[day])
                targets[day] = (0.0, "time_off", (
                    TARGET_REASON_MESSAGES["time_off"].format(names) if names
                    else TARGET_REASON_MESSAGES["time_off_unnamed"]))
            elif planned.get(day) and holiday_names.get(day):
                # Still `non_working_day` as a code, but the message can name the holiday.
                targets[day] = (0.0, "non_working_day",
                                TARGET_REASON_MESSAGES["public_holiday"].format(
                                    ", ".join(holiday_names[day])))
            else:
                targets[day] = (0.0, "non_working_day",
                                TARGET_REASON_MESSAGES["non_working_day"])
        return targets

    def _flexible_targets_by_work_day(self, employee, days, tz):
        """Flexible schedule: hours per day on the first (weekly / per day) weekdays,
        lowered by approved leave and set to 0 on public holidays."""
        calendar = employee.resource_calendar_id
        hours_per_day = float(calendar.hours_per_day or 0.0) or 8.0
        weekly = float(calendar.full_time_required_hours or 0.0)
        days_per_week = round(weekly / hours_per_day) if weekly else 5
        weekdays = set(range(min(max(days_per_week, 1), 7)))

        windows = {}
        for day in days:
            start, end = _work_day_bounds(day, tz)
            windows[day] = (pytz.utc.localize(start), pytz.utc.localize(end))
        holiday_names = self._holiday_names_by_day(employee, windows, days)

        leave_hours = {}     # day -> hours off (hours_per_day for a full day)
        leave_names = {}
        leaves = request.env["hr.leave"].search([
            ("employee_id", "=", employee.id),
            ("state", "=", "validate"),
            ("request_date_from", "<=", max(days)),
            ("request_date_to", ">=", min(days)),
        ])
        for leave in leaves:
            partial = leave.request_unit_half or leave.request_unit_hours
            day = leave.request_date_from
            while day <= leave.request_date_to:
                if partial:
                    off = min(float(leave.number_of_hours or 0.0), hours_per_day)
                else:
                    off = hours_per_day
                leave_hours[day] = min(leave_hours.get(day, 0.0) + off, hours_per_day)
                names = leave_names.setdefault(day, [])
                name = leave.holiday_status_id.name
                if name and name not in names:
                    names.append(name)
                day += timedelta(days=1)

        targets = {}
        for day in days:
            if day.weekday() not in weekdays:
                targets[day] = (0.0, "non_working_day",
                                TARGET_REASON_MESSAGES["non_working_day"])
            elif holiday_names.get(day):
                targets[day] = (0.0, "non_working_day",
                                TARGET_REASON_MESSAGES["public_holiday"].format(
                                    ", ".join(holiday_names[day])))
            else:
                hours = max(hours_per_day - leave_hours.get(day, 0.0), 0.0)
                if hours:
                    targets[day] = (hours, None, None)
                else:
                    names = ", ".join(leave_names.get(day, []))
                    targets[day] = (0.0, "time_off", (
                        TARGET_REASON_MESSAGES["time_off"].format(names) if names
                        else TARGET_REASON_MESSAGES["time_off_unnamed"]))
        return targets

    def _holiday_names_by_day(self, employee, windows, days):
        """`{day: [names]}` of company-wide closures (public holidays) overlapping each day's window.
        Only used for the message, so a lookup failure falls back to the generic text."""
        if not days:
            return {}
        try:
            span_start = min(windows[d][0] for d in days).replace(tzinfo=None)
            span_end = max(windows[d][1] for d in days).replace(tzinfo=None)
            closures = request.env["resource.calendar.leaves"].search([
                ("resource_id", "=", False),
                ("calendar_id", "in", [False, employee.resource_calendar_id.id]),
                ("company_id", "in", [False, employee.company_id.id]),
                ("date_from", "<", span_end),
                ("date_to", ">", span_start),
            ])
        except Exception:
            _logger.exception(
                "Could not read public holidays for employee %s.", employee.id)
            return {}
        names = {}
        for day in days:
            start, end = (w.replace(tzinfo=None) for w in windows[day])
            for closure in closures:
                if closure.date_from < end and closure.date_to > start \
                        and closure.name and closure.name not in names.get(day, []):
                    names.setdefault(day, []).append(closure.name)
        return names

    def _work_day_payload(self, day, rows, tz, target=None, shifts=None):
        """One grouped row: a work day, its sessions and any published Planning *shifts*."""
        first_in = rows[0].get("check_in")
        open_rows = [r for r in rows if not r.get("check_out")]
        last_out = max((r["check_out"] for r in rows if r.get("check_out")),
                       default=None)

        if open_rows:
            # Any unfinished session makes the whole day unfinished.
            status = "active"
            time_info = "%s - Present" % _time_display(first_in, tz)
        else:
            status = "completed"
            time_info = "%s - %s" % (_time_display(first_in, tz),
                                     _time_display(last_out, tz))

        target_hours, target_reason, target_message = (
            target if target else (None, None, None))

        # The day's total, not one session's; open sessions contribute nothing (no end yet).
        total_hours = sum(
            _duration_hours(r.get("check_in"), r.get("check_out")) or 0.0
            for r in rows)

        # `date` spans the day's FIRST check-in to LAST check-out; an open session collapses it to check-in.
        first_in_local = _local_time(first_in, tz)
        last_out_local = None if open_rows else _local_time(last_out, tz)
        return {
            "date": (_date_range_display(first_in_local, last_out_local)
                     or _work_day_label(day)),
            "work_date": day.isoformat(),
            "time_info": time_info,
            "status": status,
            "shift_duration": _duration_display(total_hours) if total_hours else None,
            # On a planned day, judged against the shift's start (the schedule's earliest slot misleads nights).
            "shift_status": (self._shift_status_for_shifts(first_in, shifts)
                             if status == "completed" and shifts else
                             self._shift_status_for_day(first_in, day, tz)
                             if status == "completed" else None),
            "session_count": len(rows),
            "sessions": self._session_events(rows, tz),
            # Expected hours for this work day; null when nothing is scheduled or the target is unknown.
            "targetDuration": (_duration_display(target_hours)
                               if target_hours else None),
            # `shift_duration` over `targetDuration` as a percentage; null when there is no target.
            "completionPercentage": _completion_percentage(
                total_hours, target_hours),
            # Null on a normal day; `time_off`, `non_working_day` or `no_schedule` when the target is zero.
            "targetReason": target_reason,
            # The same reason as a sentence the app can show as-is; null on a normal day.
            "targetReasonMessage": target_message,
            # Published Planning shifts this row was grouped by; empty without Planning or a shift.
            "plannedShifts": [self._planned_shift_payload(shift, tz)
                              for shift in shifts or []],
        }

    def _day_average_rows(self, days, tz):
        """Per-day rows for the averages: first check-in and the day's total, not per session."""
        rows = []
        for day_rows in days.values():
            total = sum(
                _duration_hours(r.get("check_in"), r.get("check_out")) or 0.0
                for r in day_rows)
            complete = [r for r in day_rows if r.get("check_out")]
            rows.append({
                "check_in": day_rows[0].get("check_in"),
                # A day with no finished session has no duration to average (falsy check_out).
                "check_out": complete[-1].get("check_out") if complete else False,
                "_total_hours": total if complete else None,
            })
        return rows

    def _average_check_in(self, rows, tz):
        """Mean check-in time of day, over *rows* from `search_read`."""
        values = []
        for row in rows:
            local = _local_time(row.get("check_in"), tz)
            if local:
                values.append(local.hour * 3600 + local.minute * 60 + local.second)
        if not values:
            return None
        avg = int(round(sum(values) / len(values)))
        hour = avg // 3600
        minute = (avg % 3600) // 60
        return datetime(2000, 1, 1, hour, minute).strftime("%I:%M %p").lstrip("0")

    def _average_worked_hours(self, rows):
        """Mean worked time per row, using the day's summed `_total_hours` when present.
        First-in to last-out would count the gaps between sessions as worked time."""
        values = []
        for row in rows:
            if not row.get("check_out"):
                continue
            if "_total_hours" in row:
                values.append(row["_total_hours"])
            else:
                values.append(_duration_hours(row.get("check_in"),
                                              row.get("check_out")))
        values = [value for value in values if value is not None]
        if not values:
            return None
        return _duration_display(sum(values) / len(values))

    @main.http.route("/api/mobile/v1/attendance/logs", type="http",
                     auth="none", methods=["GET"], csrf=False)
    def attendance_logs(self, **kwargs):
        """Attendance history, one row per work day; ``group=session`` returns one row per record."""
        user, error = self._authenticate_attendance()
        if error:
            return error

        args = request.httprequest.args
        tz = self._mobile_timezone(user)
        grouped = (args.get("group") or "day").strip().lower() != "session"
        start_date, end_date, period_error = self._attendance_period(args, tz)
        if period_error:
            return period_error

        page = _parse_positive_int(args.get("page"), 1)
        limit = _parse_positive_int(args.get("limit"), DEFAULT_LOG_LIMIT, MAX_LOG_LIMIT)
        offset = (page - 1) * limit

        if not grouped:
            return self._session_logs_response(
                user, tz, start_date, end_date, page, limit, offset)

        # Grouped mode works over a bounded period (default: current work month); buckets are built in Python.
        if not (start_date and end_date):
            today = _work_day(datetime.utcnow(), tz) or datetime.utcnow().date()
            start_date = today.replace(day=1)
            end_date = today.replace(day=monthrange(today.year, today.month)[1])

        # The window is in WORK days: filtering raw check_in by calendar month would drop night-shift rows.
        start_utc, _ = _work_day_bounds(start_date, tz)
        _, end_utc = _work_day_bounds(end_date, tz)

        # Widen the window for shifts straddling month edges; rows are kept by the day they were FILED.
        employee = user.employee_id
        shifts = self._published_shifts(
            employee, start_utc - PLANNING_LOOKAROUND, end_utc + PLANNING_LOOKAROUND)
        fetch_start, fetch_end = start_utc, end_utc
        if shifts:
            fetch_start = min(start_utc, min(
                s["start_datetime"] for s in shifts) - PLANNING_EARLY_CHECKIN)
            fetch_end = max(end_utc, max(s["end_datetime"] for s in shifts))
        domain = [
            ("employee_id", "=", employee.id),
            ("check_in", ">=", fetch_start),
            ("check_in", "<", fetch_end),
        ]

        rows = request.env["hr.attendance"].search_read(
            domain, ["id", "check_in", "check_out", "in_location", "out_location"])
        days = self._group_rows_by_work_day(rows, tz, shifts)
        if shifts:
            days = OrderedDict((day, day_rows) for day, day_rows in days.items()
                               if start_date <= day <= end_date)
        shifts_by_day = self._shifts_by_day(shifts, tz)
        if shifts:
            # One target per shift, breaks out (see `_shift_hours`); the row's
            # target and each shift's displayed duration use the same number.
            breaks = self._schedule_breaks(employee)
            for shift in shifts:
                shift["_target_hours"] = _shift_hours(shift, breaks)

        # Pagination is over DAYS; a month is at most 31 buckets, so the slice is bounded by the domain.
        day_keys = list(days)
        page_days = day_keys[offset:offset + limit]
        total = len(day_keys)

        # Averages stay period-wide and become per-day (`_day_average_rows`).
        average_rows = self._day_average_rows(days, tz)

        targets = self._targets_by_work_day(
            employee, [day for day in page_days if day not in shifts_by_day],
            tz)
        # A planned shift wins over the schedule, time off and holidays; a 0% shift defers to the schedule.
        for day in page_days:
            planned = sum(s["_target_hours"] for s in shifts_by_day.get(day, []))
            if planned:
                targets[day] = (planned, None, None)
        missing = [day for day in page_days
                   if day in shifts_by_day and day not in targets]
        if missing:
            targets.update(self._targets_by_work_day(
                employee, missing, tz))

        return self._json(
            success=True,
            message="Attendance logs fetched successfully",
            data={
                "logs": [self._work_day_payload(day, days[day], tz,
                                                targets.get(day),
                                                shifts_by_day.get(day))
                         for day in page_days],
                "avg_in_time": self._average_check_in(average_rows, tz),
                "avg_worked_hour": self._average_worked_hours(average_rows),
                "pagination": {
                    "page": page,
                    "limit": limit,
                    "total": total,
                    "has_next": offset + limit < total,
                },
            },
        )

    def _session_logs_response(self, user, tz, start_date, end_date,
                               page, limit, offset):
        """The pre-grouping payload, one row per `hr.attendance` record, kept for older app builds."""
        domain = [("employee_id", "=", user.employee_id.id)]
        if start_date and end_date:
            start_utc, _ = _local_date_bounds(start_date, tz)
            _, end_utc = _local_date_bounds(end_date, tz)
            domain.extend([
                ("check_in", ">=", start_utc),
                ("check_in", "<=", end_utc),
            ])

        Attendance = request.env["hr.attendance"]
        page_attendances = Attendance.search(
            domain, order="check_in desc", limit=limit, offset=offset)
        total = Attendance.search_count(domain)
        period_rows = Attendance.search_read(domain, ["check_in", "check_out"])

        return self._json(
            success=True,
            message="Attendance logs fetched successfully",
            data={
                "logs": [self._log_payload(attendance, tz)
                         for attendance in page_attendances],
                "avg_in_time": self._average_check_in(period_rows, tz),
                "avg_worked_hour": self._average_worked_hours(period_rows),
                "pagination": {
                    "page": page,
                    "limit": limit,
                    "total": total,
                    "has_next": offset + limit < total,
                },
            },
        )

    @staticmethod
    def _action_attendance_payload(attendance, action):
        """`data.attendance` for an action; shared by fresh and replayed results so they look identical."""
        checked_in = action == "check_in"
        lat = attendance.in_latitude if checked_in else attendance.out_latitude
        lon = attendance.in_longitude if checked_in else attendance.out_longitude
        return {
            "id": attendance.id,
            "status": "checked_in" if checked_in else "checked_out",
            "check_in": _iso_utc(attendance.check_in),
            "check_out": _iso_utc(attendance.check_out),
            "latitude": lat or None,
            "longitude": lon or None,
            "location_url": "https://maps.google.com?q=%s,%s" % (lat, lon)
                            if lat and lon else None,
        }

    def _replayed_action(self, employee, action):
        """The attendance already satisfying *action* within `ACTION_REPLAY_WINDOW`, else empty.
        A retry after a lost response gets 200, not 409; sudo is scoped to the token's employee."""
        Attendance = request.env["hr.attendance"].sudo()
        scope = [
            ("employee_id", "=", employee.id),
            ("employee_id.company_id", "in", self._allowed_company_ids()),
        ]
        since = datetime.utcnow() - ACTION_REPLAY_WINDOW
        open_att = Attendance.search(scope + [("check_out", "=", False)], limit=1)
        if action == "check_in":
            if open_att and open_att.check_in and open_att.check_in >= since:
                return open_att
            return Attendance
        if open_att:
            # Still checked in: a check-out is real work, never a replay.
            return Attendance
        last_out = Attendance.search(
            scope + [("check_out", "!=", False)],
            order="check_out desc", limit=1)
        if last_out and last_out.check_out >= since:
            return last_out
        return Attendance

    @main.http.route("/api/mobile/v1/attendance/action", type="http",
                     auth="none", methods=["POST"], csrf=False, readonly=False)
    def attendance_action(self, **kwargs):
        payload = self._payload()

        user, error = self._authenticate_attendance()
        if error:
            return error

        action = payload.get("action")
        if action not in ("check_in", "check_out"):
            return self._error("invalid_action",
                               "Action must be either check_in or check_out.")

        latitude = payload.get("latitude")
        longitude = payload.get("longitude")
        if (latitude is None) != (longitude is None):
            return self._error("location_required",
                               "Both latitude and longitude must be provided together.")
        if latitude is not None:
            try:
                latitude = float(latitude)
                longitude = float(longitude)
            except (TypeError, ValueError):
                return self._error("invalid_location",
                                   "latitude and longitude must be numbers.")
            if not (-90.0 <= latitude <= 90.0):
                return self._error("invalid_location",
                                   "latitude must be between -90 and 90.")
            if not (-180.0 <= longitude <= 180.0):
                return self._error("invalid_location",
                                   "longitude must be between -180 and 180.")

        employee = user.employee_id

        # A recent repeat is answered with the existing record, before the GPS gate:
        # a replay records nothing, and the original action already passed the fence.
        replayed = self._replayed_action(employee, action)
        if replayed:
            _logger.info(
                "Mobile attendance %s for employee %s answered as a replay of "
                "attendance %s (already recorded).",
                action, employee.id, replayed.id)
            return self._json(
                success=True,
                message="You are already checked in." if action == "check_in"
                        else "You are already checked out.",
                data={
                    "attendance": self._action_attendance_payload(replayed, action),
                    "already_recorded": True,
                },
            )

        # GPS fence is resolved per employee.
        geofence = employee._mobile_attendance_geofence()
        gps_required = geofence["enabled"] and (
            geofence["checkin_required"] if action == "check_in"
            else geofence["checkout_required"]
        )
        if gps_required:
            if latitude is None:
                return self._error("location_required",
                                   "Location is required for this attendance action.")
            if not geofence["latitude"] or not geofence["longitude"]:
                return self._error("company_location_missing",
                                   "Company attendance location is not configured.",
                                   status=500)
            distance = _haversine_meters(
                latitude, longitude,
                geofence["latitude"], geofence["longitude"],
            )
            if distance > geofence["boundary_meters"]:
                _logger.info(
                    "Attendance %s rejected for employee %s: %.0f m from the "
                    "%s geofence (limit %s m).",
                    action, employee.id, distance, geofence["source"],
                    geofence["boundary_meters"],
                )
                return self._error("location_out_of_range",
                                   "You are outside the allowed attendance location.")

        # Explicit sudo query with the company scope applied by hand.
        open_att = request.env["hr.attendance"].sudo().search([
            ("employee_id", "=", employee.id),
            ("check_out", "=", False),
            ("employee_id.company_id", "in", self._allowed_company_ids()),
        ], limit=1)
        state = "checked_in" if open_att else "checked_out"
        if action == "check_in" and state == "checked_in":
            return self._error("already_checked_in", "You are already checked in.",
                               status=409)

        # No "one completed session per day" rule: stepping out and back is normal for night workers.

        if action == "check_out" and state != "checked_in":
            return self._error("not_checked_in", "You are not checked in.",
                               status=409)

        # Use Odoo's native attendance action so its own validation applies.
        geo_information = {"mode": "systray", "browser": "Mobile App"}
        if latitude is not None:
            geo_information.update({"latitude": latitude, "longitude": longitude})
        # Everything that writes runs in one savepoint, so an error response means nothing was
        # committed (a returned error would otherwise still commit the attendance row).
        try:
            with request.env.cr.savepoint():
                attendance = employee.sudo()._attendance_action_change(geo_information)
                if not attendance:
                    raise _AttendanceNotRecorded()
                # Mark this side's location as from the mobile app, inside the savepoint.
                if latitude is not None:
                    attendance.sudo().write({
                        "mobile_check_in_location_enabled" if action == "check_in"
                        else "mobile_check_out_location_enabled": True,
                    })
        except (UserError, ValidationError) as exc:
            # Odoo's own validation, phrased for a person -- safe to surface.
            _logger.info(
                "Mobile attendance %s rejected by Odoo for employee %s: %s",
                action, employee.id, exc)
            return self._error(
                "attendance_action_rejected",
                str(exc.args[0]) if exc.args
                else "This attendance action could not be completed.",
                status=409)
        except AccessError:
            _logger.info(
                "Mobile attendance %s denied by access rules for employee %s.",
                action, employee.id)
            return self._error(
                "attendance_access_denied",
                "You do not have permission to record attendance.",
                status=403)
        except (IntegrityError, OperationalError, ConcurrencyError):
            # Re-raised so Odoo's request wrapper retries these transient concurrency errors;
            # the savepoint has already unwound the partial write.
            raise
        except _AttendanceNotRecorded:
            # Defensive: the action is expected to return the record; log if it does not.
            _logger.error(
                "Mobile attendance %s returned no record for employee %s.",
                action, employee.id)
            return self._error(
                "attendance_action_failed",
                "Unable to record attendance at this time.",
                status=500)
        except Exception:
            # Never leak a traceback to the app, never discard it either: it is logged server-side.
            _logger.exception(
                "Mobile attendance %s failed unexpectedly for employee %s "
                "(uid=%s).", action, employee.id, request.env.uid)
            return self._error(
                "attendance_action_failed",
                "Unable to record attendance at this time.",
                status=500)

        return self._json(
            success=True,
            message="Checked in successfully" if action == "check_in"
                    else "Checked out successfully",
            data={"attendance": self._action_attendance_payload(attendance, action)},
        )
