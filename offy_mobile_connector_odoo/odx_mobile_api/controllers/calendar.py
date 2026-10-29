import calendar as py_calendar
from datetime import date, datetime, time, timedelta

import pytz
from markupsafe import Markup, escape

from odoo import fields
from odoo.exceptions import AccessError
from odoo.http import request
from odoo.tools import html2plaintext

from . import main
from .main import API_KEY_SCOPE
from .timeoff import STAGE_BY_STATE


TYPE_COLORS = {
    "meeting": "#7E57C2",
    "time_off": "#42A5F5",
    "public_holiday": "#EF5350",
}


def _parse_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


# Single shared implementation lives in main.py.
_parse_date = main.parse_date
_parse_bool = main.parse_bool


def _parse_time(value):
    """Accept the mobile API's 24-hour time plus the UI's 12-hour display."""
    if not isinstance(value, str):
        return None
    value = value.strip()
    for fmt in ("%H:%M", "%H:%M:%S", "%I:%M %p", "%I:%M%p"):
        try:
            return datetime.strptime(value.upper(), fmt).time()
        except ValueError:
            continue
    return None




def _user_tz(user):
    """Module-level shim over `MobileApiAuth._mobile_timezone`, keeping its employee-tz fallback.
    A plain function because home.py calls the bounds helpers without a controller instance."""
    return main.MobileApiAuth()._mobile_timezone(user)


def _day_bounds_utc(user, target_date):
    tz = _user_tz(user)
    start_local = tz.localize(datetime.combine(target_date, time.min))
    end_local = start_local + timedelta(days=1)
    return (
        start_local.astimezone(pytz.UTC).replace(tzinfo=None),
        end_local.astimezone(pytz.UTC).replace(tzinfo=None),
    )


def _month_bounds_utc(user, year, month):
    first = date(year, month, 1)
    if month == 12:
        next_first = date(year + 1, 1, 1)
    else:
        next_first = date(year, month + 1, 1)
    start_utc, _ = _day_bounds_utc(user, first)
    end_utc, _ = _day_bounds_utc(user, next_first)
    return first, next_first - timedelta(days=1), start_utc, end_utc


def _local_datetime(user, dt):
    if not dt:
        return None
    return fields.Datetime.context_timestamp(user, dt).replace(tzinfo=None)


def _local_iso(user, dt):
    local_dt = _local_datetime(user, dt)
    return local_dt.isoformat(timespec="seconds") if local_dt else None


def _time_text(local_dt, include_period=True):
    if not local_dt:
        return ""
    fmt = "%I:%M %p" if include_period else "%I:%M"
    return local_dt.strftime(fmt).lstrip("0").lower()


def _time_display(user, start_dt, end_dt, all_day):
    if all_day:
        return "All day"
    start_local = _local_datetime(user, start_dt)
    end_local = _local_datetime(user, end_dt)
    if not start_local:
        return None
    if not end_local:
        return _time_text(start_local)
    if start_local.date() != end_local.date():
        return "%s - %s" % (
            start_local.strftime("%b %d %I:%M %p").replace(" 0", " ").lower(),
            end_local.strftime("%b %d %I:%M %p").replace(" 0", " ").lower(),
        )
    return "%s - %s" % (
        _time_text(start_local, include_period=False),
        _time_text(end_local),
    )


def _datetime_date_span(user, start_dt, end_dt):
    start_local = _local_datetime(user, start_dt)
    end_local = _local_datetime(user, end_dt) or start_local
    if not start_local:
        return []
    start_date = start_local.date()
    end_date = end_local.date()
    if end_local.time() == time.min and end_date > start_date:
        end_date -= timedelta(days=1)
    return _date_span(start_date, end_date)


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


def _date_iso(value):
    return value.isoformat() if value else None


def _clean_note(html):
    note = html2plaintext(html or "").strip()
    if "*Organized by*" in note:
        note = note.split("*Organized by*", 1)[0].strip()
    return note or None


class MobileApiCalendar(main.MobileApiAuth):
    """Mobile Calendar month/day APIs."""

    def _event_is_deletable(self, event, user):
        """Whether the caller may delete this event: organizer only, plus Odoo's live unlink access check."""
        if not event or event.user_id.id != user.id:
            return False
        try:
            return event.has_access("unlink")
        except AccessError:
            return False

    def _event_is_editable(self, event, user):
        """Whether the caller may edit this event: organizer only, plus Odoo's live write access check."""
        if not event or event.user_id.id != user.id:
            return False
        try:
            return event.has_access("write")
        except AccessError:
            return False

    def _authenticate_calendar(self, need_write=False):
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

        feature = request.env["mobile.feature"].sudo().search(
            [("code", "=", "calendar")], limit=1
        )
        if not feature or not feature.active:
            return None, self._json(success=False, code="calendar_disabled",
                                    message="Calendar is not enabled for the mobile app.",
                                    status=403)
        if not self._mobile_feature_allowed(user, "calendar"):
            return None, self._json(success=False, code="calendar_access_denied",
                                    message="You do not have permission to %s calendar."
                                            % ("edit" if need_write else "view"),
                                    status=403)

        if not user.employee_id:
            return None, self._json(success=False, code="employee_not_linked",
                                    message="No employee is linked to this mobile user.",
                                    status=404)
        return user, None

    def _meeting_items(self, user, start_utc, end_utc):
        partner_id = user.partner_id.id
        domain = [
            ("active", "=", True),
            ("start", "<", end_utc),
            ("stop", ">", start_utc),
            # Exclude the mirror event Odoo creates for an approved leave.
            ("res_model", "!=", "hr.leave"),
            "|",
            ("user_id", "=", user.id),
            ("partner_ids", "in", [partner_id]),
        ]
        try:
            events = request.env["calendar.event"].search(domain, order="start asc, id asc")
        except AccessError:
            return []

        items = []
        for event in events:
            if event.allday:
                item_dates = _date_span(event.start_date, event.stop_date)
                start_value = _date_iso(event.start_date)
                end_value = _date_iso(event.stop_date)
                sort_dt = datetime.combine(event.start_date or date.min, time.min)
            else:
                item_dates = _datetime_date_span(user, event.start, event.stop)
                start_value = _local_iso(user, event.start)
                end_value = _local_iso(user, event.stop)
                sort_dt = _local_datetime(user, event.start) or datetime.min

            note = _clean_note(event.notes) or _clean_note(event.description)
            status = event.current_status or event.show_as or "busy"
            items.append({
                "_dates": item_dates,
                "_sort_dt": sort_dt,
                "id": "calendar.event:%s" % event.id,
                "source_model": "calendar.event",
                "source_id": event.id,
                "type": "meeting",
                "title": event.name,
                "subtitle": note,
                "start": start_value,
                "end": end_value,
                "time_display": _time_display(user, event.start, event.stop, event.allday),
                "all_day": bool(event.allday),
                "status": status,
                "color": TYPE_COLORS["meeting"],
                "is_deletable": self._event_is_deletable(event, user),
                "is_editable": self._event_is_editable(event, user),
            })
        return items

    def _time_off_items(self, user, start_utc, end_utc):
        employee = user.employee_id
        domain = [
            ("employee_id", "=", employee.id),
            ("date_from", "<", end_utc),
            ("date_to", ">", start_utc),
            # Approved leave only: the calendar shows what is actually happening.
            ("state", "=", "validate"),
        ]
        try:
            leaves = request.env["hr.leave"].search(domain, order="date_from asc, id asc")
        except AccessError:
            return []

        items = []
        for leave in leaves:
            start_date = leave.request_date_from or (
                _local_datetime(user, leave.date_from).date() if leave.date_from else None
            )
            end_date = leave.request_date_to or (
                _local_datetime(user, leave.date_to).date() if leave.date_to else start_date
            )
            # Same wording Odoo's own mirror `calendar.event` uses.
            leave_type = leave.holiday_status_id.name or leave.name or "Time Off"
            title = "%s on Time Off : %s" % (
                leave.employee_id.name or user.name, leave.duration_display)
            reason = leave.sudo().private_name
            subtitle = ("%s — %s" % (leave_type, reason)
                       if reason and reason != leave_type else leave_type)
            items.append({
                "_dates": _date_span(start_date, end_date),
                "_sort_dt": datetime.combine(start_date or date.min, time.min),
                "id": "hr.leave:%s" % leave.id,
                "source_model": "hr.leave",
                "source_id": leave.id,
                "type": "time_off",
                "title": title,
                "subtitle": subtitle,
                "start": _date_iso(start_date),
                "end": _date_iso(end_date),
                "time_display": "All day",
                "all_day": True,
                "status": STAGE_BY_STATE.get(leave.state, leave.state),
                "color": TYPE_COLORS["time_off"],
                "is_deletable": False,
            })
        return items

    def _public_holiday_items(self, user, start_utc, end_utc):
        employee = user.employee_id
        calendar = employee.resource_calendar_id or employee.company_id.resource_calendar_id
        # Scope from the REQUEST, never a field read off the employee.
        company_ids = self._allowed_company_ids()
        company = employee.company_id or request.env.company

        # Public holidays are working-time configuration, not personal records.
        leaves = request.env["resource.calendar.leaves"].sudo().search([
            ("resource_id", "=", False),
            ("date_from", "<", end_utc),
            ("date_to", ">", start_utc),
            ("company_id", "in", [False] + company_ids),
        ], order="date_from asc, id asc")

        items = []
        for leave in leaves:
            if leave.calendar_id and calendar and leave.calendar_id != calendar:
                continue
            item_dates = _datetime_date_span(user, leave.date_from, leave.date_to)
            first_date = item_dates[0] if item_dates else None
            last_date = item_dates[-1] if item_dates else first_date
            items.append({
                "_dates": item_dates,
                "_sort_dt": datetime.combine(first_date or date.min, time.min),
                "id": "resource.calendar.leaves:%s" % leave.id,
                "source_model": "resource.calendar.leaves",
                "source_id": leave.id,
                "type": "public_holiday",
                "title": leave.name or "Public Holiday",
                "subtitle": "Public Holiday",
                "start": _date_iso(first_date),
                "end": _date_iso(last_date),
                "time_display": "All day",
                "all_day": True,
                "status": "confirmed",
                "color": TYPE_COLORS["public_holiday"],
                "is_deletable": False,
            })
        return items

    def _collect_items(self, user, start_utc, end_utc):
        items = []
        items.extend(self._meeting_items(user, start_utc, end_utc))
        items.extend(self._time_off_items(user, start_utc, end_utc))
        items.extend(self._public_holiday_items(user, start_utc, end_utc))
        return items

    def _public_item(self, item):
        return {key: value for key, value in item.items() if not key.startswith("_")}

    def _created_event_payload(self, event, user):
        """Mobile-safe response for an event just created by this user."""
        if event.allday:
            start = _date_iso(event.start_date)
            end = _date_iso(event.stop_date)
        else:
            start = _local_iso(user, event.start)
            end = _local_iso(user, event.stop)
        return {
            "id": "calendar.event:%s" % event.id,
            "source_model": "calendar.event",
            "source_id": event.id,
            "type": "meeting",
            "title": event.name,
            "subtitle": _clean_note(event.notes),
            "start": start,
            "end": end,
            "time_display": _time_display(user, event.start, event.stop, event.allday),
            "all_day": bool(event.allday),
            "status": event.current_status or event.show_as or "busy",
            "color": TYPE_COLORS["meeting"],
            "is_deletable": self._event_is_deletable(event, user),
            "is_editable": self._event_is_editable(event, user),
        }

    @main.http.route("/api/mobile/v1/calendar/events", type="http", auth="none",
                     methods=["POST"], csrf=False, readonly=False)
    def calendar_event_create(self, **kwargs):
        """Create a personal event. Dates are YYYY-MM-DD; times HH:MM 24h ("02:30 PM" also accepted).
        All-day events ignore both time fields."""
        user, err = self._authenticate_calendar(need_write=True)
        if err:
            return err
        payload = self._payload()
        payload.update(kwargs or {})

        title = (payload.get("title") or "").strip()
        if not title:
            return self._json(success=False, code="missing_title",
                              message="title is required.", status=400)
        if len(title) > 255:
            return self._json(success=False, code="invalid_title",
                              message="title must be at most 255 characters.", status=400)

        all_day = _parse_bool(payload.get("all_day"))
        if all_day is None:
            return self._json(success=False, code="invalid_all_day",
                              message="all_day must be true or false.", status=400)
        start_date = _parse_date(payload.get("start_date"))
        end_date = _parse_date(payload.get("end_date"))
        if not start_date or not end_date:
            return self._json(success=False, code="invalid_date",
                              message="start_date and end_date must use YYYY-MM-DD format.",
                              status=400)
        if end_date < start_date:
            return self._json(success=False, code="invalid_date_range",
                              message="end_date must be on or after start_date.", status=400)

        notes = (payload.get("notes") or "").strip()
        if len(notes) > 10_000:
            return self._json(success=False, code="invalid_notes",
                              message="notes must be at most 10000 characters.", status=400)
        values = {
            "name": title,
            "user_id": user.id,
            "partner_ids": [(4, user.partner_id.id)],
            "allday": all_day,
            "notes": Markup("<p>%s</p>") % escape(notes) if notes else False,
        }
        if all_day:
            # Date values are inclusive in the mobile response.
            values.update({"start_date": start_date, "stop_date": end_date})
        else:
            start_time = _parse_time(payload.get("start_time"))
            end_time = _parse_time(payload.get("end_time"))
            if not start_time or not end_time:
                return self._json(success=False, code="invalid_time",
                                  message="start_time and end_time are required for a timed event.",
                                  status=400)
            tz = _user_tz(user)
            local_start = tz.localize(datetime.combine(start_date, start_time))
            local_end = tz.localize(datetime.combine(end_date, end_time))
            if local_end <= local_start:
                return self._json(success=False, code="invalid_time_range",
                                  message="end date and time must be after start date and time.",
                                  status=400)
            values.update({
                "start": local_start.astimezone(pytz.UTC).replace(tzinfo=None),
                "stop": local_end.astimezone(pytz.UTC).replace(tzinfo=None),
            })

        try:
            event = request.env["calendar.event"].create(values)
        except AccessError:
            return self._json(success=False, code="calendar_access_denied",
                              message="You do not have permission to create this event.",
                              status=403)

        return self._json(success=True, message="Calendar event created successfully",
                          data={"event": self._created_event_payload(event, user)},
                          status=201)

    @main.http.route("/api/mobile/v1/calendar/events/<event_id>", type="http",
                     auth="none", methods=["PATCH"], csrf=False, readonly=False)
    def calendar_event_update(self, event_id, **kwargs):
        """Update the caller's own event; same fields as `calendar_event_create`, full-record replace."""
        try:
            event_id = int(event_id)
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_event_id",
                              message="event_id must be an integer.", status=400)

        user, err = self._authenticate_calendar(need_write=True)
        if err:
            return err

        try:
            event = request.env["calendar.event"].search(
                [("id", "=", event_id)], limit=1)
        except AccessError:
            event = request.env["calendar.event"]
        if not event:
            return self._json(success=False, code="calendar_event_not_found",
                              message="Calendar event not found.", status=404)
        if event.user_id.id != user.id or not self._event_is_editable(event, user):
            return self._json(success=False, code="calendar_event_update_denied",
                              message="You can only edit events you created.",
                              status=403)

        payload = self._payload()
        payload.update(kwargs or {})

        title = (payload.get("title") or "").strip()
        if not title:
            return self._json(success=False, code="missing_title",
                              message="title is required.", status=400)
        if len(title) > 255:
            return self._json(success=False, code="invalid_title",
                              message="title must be at most 255 characters.", status=400)

        all_day = _parse_bool(payload.get("all_day"))
        if all_day is None:
            return self._json(success=False, code="invalid_all_day",
                              message="all_day must be true or false.", status=400)
        start_date = _parse_date(payload.get("start_date"))
        end_date = _parse_date(payload.get("end_date"))
        if not start_date or not end_date:
            return self._json(success=False, code="invalid_date",
                              message="start_date and end_date must use YYYY-MM-DD format.",
                              status=400)
        if end_date < start_date:
            return self._json(success=False, code="invalid_date_range",
                              message="end_date must be on or after start_date.", status=400)

        notes = (payload.get("notes") or "").strip()
        if len(notes) > 10_000:
            return self._json(success=False, code="invalid_notes",
                              message="notes must be at most 10000 characters.", status=400)
        values = {
            "name": title,
            "allday": all_day,
            "notes": Markup("<p>%s</p>") % escape(notes) if notes else False,
        }
        if all_day:
            values.update({"start_date": start_date, "stop_date": end_date})
        else:
            start_time = _parse_time(payload.get("start_time"))
            end_time = _parse_time(payload.get("end_time"))
            if not start_time or not end_time:
                return self._json(success=False, code="invalid_time",
                                  message="start_time and end_time are required for a timed event.",
                                  status=400)
            tz = _user_tz(user)
            local_start = tz.localize(datetime.combine(start_date, start_time))
            local_end = tz.localize(datetime.combine(end_date, end_time))
            if local_end <= local_start:
                return self._json(success=False, code="invalid_time_range",
                                  message="end date and time must be after start date and time.",
                                  status=400)
            values.update({
                "start": local_start.astimezone(pytz.UTC).replace(tzinfo=None),
                "stop": local_end.astimezone(pytz.UTC).replace(tzinfo=None),
            })

        try:
            event.write(values)
        except AccessError:
            return self._json(success=False, code="calendar_access_denied",
                              message="You do not have permission to update this event.",
                              status=403)

        return self._json(success=True, message="Calendar event updated successfully",
                          data={"event": self._created_event_payload(event, user)})

    @main.http.route("/api/mobile/v1/calendar/events/<event_id>", type="http",
                     auth="none", methods=["DELETE"], csrf=False, readonly=False)
    def calendar_event_delete(self, event_id, **kwargs):
        """Delete one event created by the authenticated mobile user."""
        try:
            event_id = int(event_id)
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_event_id",
                              message="event_id must be an integer.", status=400)

        user, err = self._authenticate_calendar(need_write=True)
        if err:
            return err

        try:
            event = request.env["calendar.event"].search(
                [("id", "=", event_id)], limit=1)
        except AccessError:
            event = request.env["calendar.event"]
        if not event:
            return self._json(success=False, code="calendar_event_not_found",
                              message="Calendar event not found.", status=404)
        if event.user_id.id != user.id or not self._event_is_deletable(event, user):
            return self._json(success=False, code="calendar_event_delete_denied",
                              message="You can only delete events you created.",
                              status=403)
        try:
            event.unlink()
        except AccessError:
            return self._json(success=False, code="calendar_event_delete_denied",
                              message="You can only delete events you created.",
                              status=403)

        return self._json(success=True, message="Calendar event deleted successfully",
                          data={"id": event_id})

    @main.http.route("/api/mobile/v1/calendar/month", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def calendar_month(self, **kwargs):
        user, err = self._authenticate_calendar()
        if err:
            return err

        raw_year = kwargs.get("year")
        raw_month = kwargs.get("month")
        if raw_year in (None, ""):
            return self._json(success=False, code="missing_year",
                              message="year is required.", status=400)
        if raw_month in (None, ""):
            return self._json(success=False, code="missing_month",
                              message="month is required.", status=400)

        year = _parse_int(raw_year)
        month = _parse_int(raw_month)
        if not year or year < 1900 or year > 2100:
            return self._json(success=False, code="invalid_year",
                              message="year must be a valid four-digit year.",
                              status=400)
        if not month or month < 1 or month > 12:
            return self._json(success=False, code="invalid_month",
                              message="month must be between 1 and 12.",
                              status=400)

        first, last, start_utc, end_utc = _month_bounds_utc(user, year, month)
        days = {
            first + timedelta(days=offset): {"item_count": 0, "types": set()}
            for offset in range((last - first).days + 1)
        }

        for item in self._collect_items(user, start_utc, end_utc):
            for item_date in item["_dates"]:
                if first <= item_date <= last:
                    days[item_date]["item_count"] += 1
                    days[item_date]["types"].add(item["type"])

        payload_days = []
        for current in sorted(days):
            info = days[current]
            payload_days.append({
                "date": current.isoformat(),
                "day": current.day,
                "item_count": info["item_count"],
                "types": sorted(info["types"]),
            })

        return self._json(success=True, message="Calendar month fetched successfully",
                          data={
                              "year": year,
                              "month": month,
                              "month_label": "%s %s" % (
                                  py_calendar.month_name[month], year),
                              "days": payload_days,
                          })

    @main.http.route("/api/mobile/v1/calendar/day", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def calendar_day(self, **kwargs):
        user, err = self._authenticate_calendar()
        if err:
            return err

        raw_date = kwargs.get("date")
        if raw_date in (None, ""):
            return self._json(success=False, code="missing_date",
                              message="date is required.", status=400)
        target_date = _parse_date(raw_date)
        if not target_date:
            return self._json(success=False, code="invalid_date",
                              message="date must use YYYY-MM-DD format.",
                              status=400)

        start_utc, end_utc = _day_bounds_utc(user, target_date)
        items = [
            item for item in self._collect_items(user, start_utc, end_utc)
            if target_date in item["_dates"]
        ]
        items.sort(key=lambda item: (
            item["all_day"],
            item["_sort_dt"],
            item["source_model"],
            item["source_id"],
        ))

        return self._json(success=True, message="Calendar day fetched successfully",
                          data={
                              "date": target_date.isoformat(),
                              "day_label": "%s, %s %s" % (
                                  target_date.strftime("%A"),
                                  target_date.strftime("%B"),
                                  target_date.day,
                              ),
                              "items": [self._public_item(item) for item in items],
                          })
