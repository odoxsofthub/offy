import calendar as py_calendar
from datetime import datetime

from odoo.exceptions import AccessError
from odoo.http import request

from . import main
from .main import API_KEY_SCOPE


def _iso_utc(dt):
    """Format a naive-UTC Odoo datetime as ISO 8601 UTC, or None."""
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ") if dt else None


def _currency_payload(currency):
    return {
        "id": currency.id,
        "name": currency.name,
        "symbol": currency.symbol or currency.name,
        "icon": currency.symbol or currency.name,
    }


class MobileApiHome(main.MobileApiAuth):
    """Home-screen card data for the mobile app; each card is a key under ``data.home``."""

    def _attendance_card(self, user):
        """Attendance home card from the linked employee's current state."""
        if not self._mobile_feature_allowed(user, "attendance"):
            return {
                "enabled": False,
                "status": None,
                "check_in": None,
                "check_out": None,
                "display_time": None,
            }

        employee = user.employee_id

        # An open session (no check_out) always wins, even if it started before today's window.
        open_att = request.env["hr.attendance"].sudo().search([
            ("employee_id", "=", employee.id),
            ("check_out", "=", False),
            ("employee_id.company_id", "in", self._allowed_company_ids()),
        ], order="check_in desc", limit=1)
        if open_att:
            check_in = _iso_utc(open_att.check_in)
            return {
                "enabled": True,
                "status": "checked_in",
                "check_in": check_in,
                "check_out": None,
                "display_time": check_in,
            }

        # Today in the employee's timezone, via `attendance.py`'s helpers so the
        # home card and the attendance log agree on which day an attendance belongs to.
        from .attendance import work_day, work_day_bounds

        tz = self._mobile_timezone(user)
        today_local = work_day(datetime.utcnow(), tz)
        day_start, day_end = work_day_bounds(today_local, tz)
        today_att = request.env["hr.attendance"].sudo().search([
            ("employee_id", "=", employee.id),
            ("check_in", ">=", day_start),
            ("check_in", "<", day_end),
            # sudo() drops the multi-company record rules, so re-apply the company scope explicitly.
            ("employee_id.company_id", "in", self._allowed_company_ids()),
        ], order="check_in desc", limit=1)

        if not today_att:
            return {
                "enabled": True,
                "status": "not_checked_in",
                "check_in": None,
                "check_out": None,
                "display_time": None,
            }

        check_in = _iso_utc(today_att.check_in)
        check_out = _iso_utc(today_att.check_out)
        return {
            "enabled": True,
            "status": "checked_out",
            "check_in": check_in,
            "check_out": check_out,
            "display_time": check_out or check_in,
        }

    def _total_remaining_leave(self, user):
        """Sum of virtual_remaining_leaves across all allocated leave types."""
        if not self._mobile_feature_allowed(user, "time_off"):
            return 0

        employee = user.employee_id
        # Company-scoped: an unscoped search would return every company's leave types.
        leave_types = request.env["hr.leave.type"].search([
            "|",
            ("company_id", "=", False),
            ("company_id", "in", self._allowed_company_ids()),
        ])
        # Company-filtered rows -- see main._allocation_rows.
        allocation_data = self._allocation_rows(leave_types, employee)

        total = 0.0
        for _name, info, requires_allocation, _type_id in allocation_data:
            # Only types the employee actually has an allocation for.
            if not requires_allocation or not info["max_leaves"]:
                continue
            total += info["virtual_remaining_leaves"]
        return total

    def _authenticate_home(self):
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
            return None, self._json(
                success=False,
                code="employee_not_linked",
                message="No employee is linked to this mobile user.",
                status=404,
            )
        return user, None

    def _recent_activities_items(self, user):
        """Latest activity feed items for the home screen."""
        from . import activity

        activity_controller = activity.MobileApiActivity()
        items = activity_controller._gather_items(user, user.employee_id, None)
        items.sort(key=activity_controller._sort_key, reverse=True)
        return [
            activity_controller._activity_payload(item)
            for item in items[:activity.HOME_LIMIT]
        ]

    def _payslip_card(self, user):
        company_currency = request.env.company.currency_id
        if not self._mobile_feature_allowed(user, "payslip"):
            return {
                "enabled": False,
                "month": None,
                "final_amount": None,
                "currency": _currency_payload(company_currency),
            }

        from .payslip import VISIBLE_STATES

        payslip = request.env["hr.payslip"].sudo().search([
            ("employee_id", "=", user.employee_id.id),
            ("state", "in", VISIBLE_STATES),
            # Re-apply the company scope dropped by sudo(); see _allowed_company_ids.
            ("employee_id.company_id", "in", self._allowed_company_ids()),
        ], order="date_to desc, date_from desc, id desc", limit=1)
        if not payslip:
            return {
                "enabled": True,
                "month": None,
                "final_amount": None,
                "currency": _currency_payload(company_currency),
            }

        month_source = payslip.date_from or payslip.date_to
        currency = payslip.currency_id or company_currency
        return {
            "enabled": True,
            "month": month_source.strftime("%B %Y") if month_source else payslip.name,
            "final_amount": main.amount_2dp(payslip.net_wage),
            "currency": _currency_payload(currency),
        }

    def _expense_card(self, user):
        tz = self._mobile_timezone(user)
        today_local = datetime.now(tz).date()
        month_name = "%s %s" % (
            py_calendar.month_name[today_local.month], today_local.year)
        currency = request.env.company.currency_id
        currency_payload = _currency_payload(currency)
        if not self._mobile_feature_allowed(user, "expense"):
            return {
                "enabled": False,
                "month": month_name,
                "total_amount": 0.0,
                "currency": currency_payload,
            }

        start_date = today_local.replace(day=1)
        last_day = py_calendar.monthrange(today_local.year, today_local.month)[1]
        end_date = today_local.replace(day=last_day)
        try:
            expenses = request.env["hr.expense"].search([
                ("employee_id", "=", user.employee_id.id),
                ("date", ">=", start_date),
                ("date", "<=", end_date),
                # Refused claims are excluded: the card answers "what have I spent".
                ("state", "!=", "refused"),
            ])
        except AccessError:
            return {
                "enabled": False,
                "month": month_name,
                "total_amount": 0.0,
                "currency": currency_payload,
            }
        return {
            "enabled": True,
            "month": month_name,
            # Sum company-currency `total_amount`: one company symbol labels the total (see expense_payload).
            "total_amount": sum(expenses.mapped("total_amount")),
            "currency": currency_payload,
        }

    def _calendar_card(self, user):
        if not self._mobile_feature_allowed(user, "calendar"):
            return {
                "enabled": False,
                "date": None,
                "items": [],
            }

        from . import calendar as calendar_controller

        tz = self._mobile_timezone(user)
        today_local = datetime.now(tz).date()
        start_utc, end_utc = calendar_controller._day_bounds_utc(user, today_local)
        controller = calendar_controller.MobileApiCalendar()
        items = [
            item for item in controller._collect_items(user, start_utc, end_utc)
            if today_local in item["_dates"]
        ]
        items.sort(key=lambda item: (
            item["all_day"],
            item["_sort_dt"],
            item["source_model"],
            item["source_id"],
        ))
        return {
            "enabled": True,
            "date": today_local.isoformat(),
            "items": [{
                "note": item["title"],
                "time": item["time_display"],
            } for item in items],
        }

    @staticmethod
    def _has_unread_notifications(user):
        """Whether the inbox has an unread row (``read_at`` unset), matching `/notifications`.
        Uses a one-row search since the badge only needs existence."""
        return bool(request.env["mobile.notification.log"].sudo().search(
            [("user_id", "=", user.id), ("read_at", "=", False)], limit=1))

    @main.http.route("/api/mobile/v1/home/recent-activities", type="http",
                     auth="none", methods=["GET"], csrf=False)
    def home_recent_activities(self, **kwargs):
        user, error = self._authenticate_home()
        if error:
            return error
        items = self._recent_activities_items(user)
        return self._json(success=True,
                          message="Recent activities fetched successfully",
                          data={
                              "items": items,
                              "recent_activities": items,
                          })

    @main.http.route("/api/mobile/v1/home", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def home(self, **kwargs):
        user, error = self._authenticate_home()
        if error:
            return error

        home = {
            "attendance": self._attendance_card(user),
            "total_remaining_leave": self._total_remaining_leave(user),
            "payslip": self._payslip_card(user),
            "expense": self._expense_card(user),
            "calendar": self._calendar_card(user),
            "has_unread_notifications": self._has_unread_notifications(user),
        }
        return self._json(success=True, message="Home data fetched successfully",
                          data={"home": home})
