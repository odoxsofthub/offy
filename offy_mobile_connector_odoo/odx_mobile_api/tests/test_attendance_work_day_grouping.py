from datetime import date, datetime, timedelta
from unittest.mock import patch

import pytz

from odoo import fields
from odoo.tests import HttpCase, tagged

PASSWORD = "work_day_pw_1234"
LOGIN = "work_day_user@test.com"
TZ = "Asia/Kolkata"


def _utc(year, month, day, hour, minute=0, second=0, tz_name=TZ):
    """A local wall-clock time as the naive UTC Odoo stores.
    Asia/Kolkata is a half-hour offset with no DST, so a bug that drops the timezone cannot pass by accident.
    """
    tz = pytz.timezone(tz_name)
    local = tz.localize(datetime(year, month, day, hour, minute, second))
    return local.astimezone(pytz.utc).replace(tzinfo=None)


@tagged("-at_install", "post_install")
class TestAttendanceWorkDayGrouping(HttpCase):
    """`/attendance/logs` groups sessions into one row per work day, keyed by the check-in calendar day."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        config = cls.env["mobile.config"].sudo().search([], limit=1)
        if not config:
            config = cls.env["mobile.config"].sudo().create({})
        cls.config = config

        cls.user = Users.create({
            "name": "Work Day User",
            "login": LOGIN,
            "password": PASSWORD,
            "tz": TZ,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Work Day User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })

    def _attendance(self, check_in, check_out=None):
        return self.env["hr.attendance"].sudo().create({
            "employee_id": self.employee.id,
            "check_in": check_in,
            "check_out": check_out,
        })

    def _token(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": LOGIN, "password": PASSWORD},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"]

    def _logs(self, month=3, year=2026, page=1, limit=50, group=None):
        url = ("/api/mobile/v1/attendance/logs"
               "?month=%s&year=%s&page=%s&limit=%s" % (month, year, page, limit))
        if group:
            url += "&group=%s" % group
        resp = self.url_open(
            url, headers={"Authorization": "Bearer %s" % self._token()})
        body = resp.json()
        self.assertEqual(resp.status_code, 200, body)
        self.assertTrue(body["success"], body)
        return body["data"]

    def _night_shift(self):
        """A shift crossing midnight plus a short session after it: two work days (the 9th and the 10th)."""
        self._attendance(_utc(2026, 3, 9, 22, 0), _utc(2026, 3, 10, 4, 0))
        self._attendance(_utc(2026, 3, 10, 4, 15), _utc(2026, 3, 10, 4, 30))

    def _two_sessions_one_day(self):
        """6h then 15m on 12 March: one work day with two sessions, for the per-day aggregation tests."""
        self._attendance(_utc(2026, 3, 12, 9, 0), _utc(2026, 3, 12, 15, 0))
        self._attendance(_utc(2026, 3, 12, 15, 15), _utc(2026, 3, 12, 15, 30))

    def test_a_night_shift_is_split_across_the_two_calendar_days(self):
        """Grouping is by the check-in calendar day, so the session after midnight is its own work day."""
        self._night_shift()
        data = self._logs()
        self.assertEqual([r["work_date"] for r in data["logs"]],
                         ["2026-03-10", "2026-03-09"])
        later, night = data["logs"]
        # The label still spans both days -- the shift really did run into the 10th.
        self.assertEqual(night["date"], "March 9-10, 2026")
        self.assertEqual(night["session_count"], 1)
        self.assertEqual(night["status"], "completed")
        self.assertEqual(later["date"], "March 10, 2026")
        self.assertEqual(later["session_count"], 1)

    def test_the_total_is_the_sum_of_a_days_own_sessions(self):
        """6h plus 15m on ONE day is 06h 15m -- the sum, not the 06h 30m span
        from first check-in to last check-out."""
        self._two_sessions_one_day()
        row = next(r for r in self._logs()["logs"]
                   if r["work_date"] == "2026-03-12")
        self.assertEqual(row["session_count"], 2)
        self.assertEqual(row["shift_duration"], "06h 15m")

    def test_a_gap_between_sessions_is_not_counted_as_worked(self):
        """Two 1-hour sessions four hours apart total 02h 00m, not 05h 00m."""
        self._attendance(_utc(2026, 3, 12, 9, 0), _utc(2026, 3, 12, 10, 0))
        self._attendance(_utc(2026, 3, 12, 13, 0), _utc(2026, 3, 12, 14, 0))
        row = next(r for r in self._logs()["logs"] if r["work_date"] == "2026-03-12")
        self.assertEqual(row["session_count"], 2)
        self.assertEqual(row["shift_duration"], "02h 00m")
        self.assertEqual(row["time_info"], "9:00 AM - 2:00 PM")

    def test_every_check_in_and_out_is_listed_in_order(self):
        self._two_sessions_one_day()
        sessions = next(r for r in self._logs()["logs"]
                        if r["work_date"] == "2026-03-12")["sessions"]
        self.assertEqual(
            [(s["type"], s["time"]) for s in sessions],
            [("check_in", "9:00 AM"), ("check_out", "3:00 PM"),
             ("check_in", "3:15 PM"), ("check_out", "3:30 PM")])
        self.assertTrue(all(s["id"] for s in sessions), sessions)
        self.assertTrue(all(s["at"].endswith("Z") for s in sessions), sessions)

    def test_sessions_group_by_the_calendar_day_they_start_on(self):
        """04:15 and 06:00 are both the 10th; the 22:00 start is the 9th."""
        self._night_shift()
        self._attendance(_utc(2026, 3, 10, 6, 0), _utc(2026, 3, 10, 14, 0))
        data = self._logs()
        self.assertEqual([r["work_date"] for r in data["logs"]],
                         ["2026-03-10", "2026-03-09"])
        self.assertEqual([r["session_count"] for r in data["logs"]], [2, 1])

    def test_an_early_morning_session_is_that_mornings_day(self):
        """No cut-over, so 00:00 is the only boundary."""
        self._attendance(_utc(2026, 3, 10, 0, 0, 1), _utc(2026, 3, 10, 7, 0))
        self.assertEqual([r["work_date"] for r in self._logs()["logs"]],
                         ["2026-03-10"])

    def test_a_session_just_before_midnight_stays_on_its_own_day(self):
        self._attendance(_utc(2026, 3, 9, 23, 59, 59), _utc(2026, 3, 10, 7, 0))
        self.assertEqual([r["work_date"] for r in self._logs()["logs"]],
                         ["2026-03-09"])

    def test_a_session_on_the_boundary_is_never_counted_twice(self):
        """The window is half-open, so no session can land in two days."""
        self._attendance(_utc(2026, 3, 10, 5, 0, 0), _utc(2026, 3, 10, 7, 0))
        data = self._logs()
        self.assertEqual(data["pagination"]["total"], 1)
        self.assertEqual(sum(r["session_count"] for r in data["logs"]), 1)

    def test_a_post_midnight_session_stays_in_the_month_it_belongs_to(self):
        """04:15 on 1 April belongs to the 31 March work day, not to April."""
        self._attendance(_utc(2026, 3, 31, 22, 0), _utc(2026, 4, 1, 4, 30))
        march = self._logs(month=3, year=2026)
        april = self._logs(month=4, year=2026)
        self.assertEqual([r["work_date"] for r in march["logs"]], ["2026-03-31"])
        self.assertEqual(april["logs"], [],
                         "it must not also appear in April: %s" % april["logs"])

    def test_an_open_session_makes_the_day_active(self):
        self._attendance(_utc(2026, 3, 9, 22, 0))
        row = self._logs()["logs"][0]
        self.assertEqual(row["work_date"], "2026-03-09")
        self.assertEqual(row["status"], "active")
        self.assertEqual(row["time_info"], "10:00 PM - Present")
        self.assertIsNone(row["shift_status"])
        self.assertEqual([s["type"] for s in row["sessions"]], ["check_in"])

    def test_a_completed_session_plus_an_open_one_is_still_active(self):
        """One unfinished session makes the whole day unfinished."""
        self._attendance(_utc(2026, 3, 12, 9, 0), _utc(2026, 3, 12, 15, 0))
        self._attendance(_utc(2026, 3, 12, 15, 15))
        row = next(r for r in self._logs()["logs"]
                   if r["work_date"] == "2026-03-12")
        self.assertEqual(row["status"], "active")
        self.assertEqual(row["session_count"], 2)
        # The finished session's 6h still counts; the open one adds nothing.
        self.assertEqual(row["shift_duration"], "06h 00m")

    def test_averages_are_per_day_not_per_session(self):
        """Averages are per day: (6h + 15m) is one 06h 15m day, not two sessions averaging 03h 07m."""
        self._two_sessions_one_day()
        data = self._logs()
        self.assertEqual(data["avg_worked_hour"], "06h 15m")

    def test_average_in_time_uses_the_days_first_check_in(self):
        """Not the 15:15 one -- the day began at 09:00."""
        self._two_sessions_one_day()
        self.assertEqual(self._logs()["avg_in_time"], "9:00 AM")

    def test_averages_span_the_period_not_the_page(self):
        for day in (9, 11, 13):
            self._attendance(_utc(2026, 3, day, 9, 0), _utc(2026, 3, day, 17, 0))
        data = self._logs(page=2, limit=1)
        self.assertEqual(len(data["logs"]), 1)
        self.assertEqual(data["avg_in_time"], "9:00 AM")
        self.assertEqual(data["avg_worked_hour"], "08h 00m")

    def test_pagination_counts_days_not_records(self):
        """Three days, four records."""
        self._night_shift()                                    # 2 records, 2 days
        self._attendance(_utc(2026, 3, 12, 9, 0), _utc(2026, 3, 12, 10, 0))
        self._attendance(_utc(2026, 3, 12, 13, 0), _utc(2026, 3, 12, 14, 0))
        data = self._logs()
        self.assertEqual(data["pagination"]["total"], 3)
        self.assertFalse(data["pagination"]["has_next"])

    def test_pages_walk_the_days_newest_first(self):
        for day in (9, 11, 13):
            self._attendance(_utc(2026, 3, day, 9, 0), _utc(2026, 3, day, 17, 0))
        first = self._logs(page=1, limit=2)
        second = self._logs(page=2, limit=2)
        self.assertEqual([r["work_date"] for r in first["logs"]],
                         ["2026-03-13", "2026-03-11"])
        self.assertTrue(first["pagination"]["has_next"])
        self.assertEqual([r["work_date"] for r in second["logs"]], ["2026-03-09"])
        self.assertFalse(second["pagination"]["has_next"])

    def test_a_page_past_the_end_is_empty_but_still_counts(self):
        self._night_shift()
        data = self._logs(page=9, limit=2)
        self.assertEqual(data["logs"], [])
        self.assertEqual(data["pagination"]["total"], 2)
        self.assertFalse(data["pagination"]["has_next"])

    def _only_row(self, month, year):
        logs = self._logs(month=month, year=year)["logs"]
        self.assertEqual(len(logs), 1, logs)
        return logs[0]

    def test_date_same_day(self):
        self._attendance(_utc(2026, 3, 12, 9, 0), _utc(2026, 3, 12, 17, 0))
        self.assertEqual(self._only_row(3, 2026)["date"], "March 12, 2026")

    def test_date_same_month_different_day(self):
        self._attendance(_utc(2026, 3, 25, 22, 0), _utc(2026, 3, 26, 6, 0))
        self.assertEqual(self._only_row(3, 2026)["date"], "March 25-26, 2026")

    def test_date_different_month_same_year(self):
        self._attendance(_utc(2026, 6, 30, 22, 0), _utc(2026, 7, 1, 6, 0))
        self.assertEqual(self._only_row(6, 2026)["date"], "June 30-July 1, 2026")

    def test_date_different_year(self):
        self._attendance(_utc(2026, 12, 31, 22, 0), _utc(2027, 1, 5, 9, 0))
        self.assertEqual(self._only_row(12, 2026)["date"],
                         "December 31, 2026-January 5, 2027")

    def test_date_without_a_checkout_is_the_check_in_date(self):
        self._attendance(_utc(2026, 3, 15, 22, 0))
        row = self._only_row(3, 2026)
        self.assertEqual(row["date"], "March 15, 2026")
        self.assertEqual(row["status"], "active")

    def test_an_open_last_session_means_no_checkout_for_the_day(self):
        """A finished session followed by an open one: the day has no checkout yet."""
        self._attendance(_utc(2026, 3, 18, 9, 0), _utc(2026, 3, 18, 12, 0))
        self._attendance(_utc(2026, 3, 18, 13, 0))
        row = self._only_row(3, 2026)
        self.assertEqual(row["date"], "March 18, 2026")
        self.assertEqual(row["session_count"], 2)

    def test_the_range_ends_at_the_days_last_checkout(self):
        """Two sessions, the second one running past midnight: the range is
        first check-in to the LATEST check-out, not the first session's."""
        self._attendance(_utc(2026, 3, 21, 9, 0), _utc(2026, 3, 21, 13, 0))
        self._attendance(_utc(2026, 3, 21, 20, 0), _utc(2026, 3, 22, 2, 0))
        row = self._only_row(3, 2026)
        self.assertEqual(row["date"], "March 21-22, 2026")
        self.assertEqual(row["session_count"], 2)

    def test_work_date_and_date_agree_on_a_single_day_session(self):
        """A 02:00 session's `work_date` and `date` describe the same calendar day."""
        self._attendance(_utc(2026, 3, 20, 2, 0), _utc(2026, 3, 20, 4, 0))
        row = self._only_row(3, 2026)
        self.assertEqual(row["work_date"], "2026-03-20")
        self.assertEqual(row["date"], "March 20, 2026")

    def _schedule(self, name, lines):
        """A schedule in the employee's timezone from `(weekday, from, to,
        period)` lines, assigned to the employee for this test only."""
        calendar = self.env["resource.calendar"].sudo().create({
            "name": name,
            "tz": TZ,
            "attendance_ids": [(5, 0, 0)] + [(0, 0, {
                "name": "%s %s" % (name, index),
                "dayofweek": weekday,
                "hour_from": hour_from,
                "hour_to": hour_to,
                "day_period": period,
            }) for index, (weekday, hour_from, hour_to, period) in enumerate(lines)],
        })
        self.employee.sudo().write({"resource_calendar_id": calendar.id, "tz": TZ})
        return calendar

    def _day_schedule(self):
        """Mon-Fri 09:00-13:00 + 14:00-18:00: 8h a day, lunch 13:00-14:00."""
        lines = []
        for weekday in "01234":
            lines += [(weekday, 9, 13, "morning"),
                      (weekday, 13, 14, "lunch"),
                      (weekday, 14, 18, "afternoon")]
        return self._schedule("TP Day 8h", lines)

    def test_one_hour_of_an_eight_hour_day_is_twelve_point_five(self):
        """The example from the request."""
        self._day_schedule()
        self._attendance(_utc(2026, 3, 11, 9, 0), _utc(2026, 3, 11, 10, 0))
        row = self._only_row(3, 2026)
        self.assertEqual(row["targetDuration"], "08h 00m")
        self.assertEqual(row["completionPercentage"], 12.5)
        self.assertIsNone(row["targetReason"], "a normal day needs no reason")
        self.assertIsNone(row["targetReasonMessage"])

    def test_a_full_day_is_one_hundred(self):
        self._day_schedule()
        self._attendance(_utc(2026, 3, 12, 9, 0), _utc(2026, 3, 12, 17, 0))
        row = self._only_row(3, 2026)
        self.assertEqual(row["targetDuration"], "08h 00m")
        self.assertEqual(row["completionPercentage"], 100.0)

    def test_overtime_is_not_capped(self):
        """9h against 8h is 112.5 -- clamping is the client's display call."""
        self._day_schedule()
        self._attendance(_utc(2026, 3, 12, 9, 0), _utc(2026, 3, 12, 18, 0))
        self.assertEqual(self._only_row(3, 2026)["completionPercentage"], 112.5)

    def test_completion_sums_every_finished_session_of_the_day(self):
        self._day_schedule()
        self._attendance(_utc(2026, 3, 13, 9, 0), _utc(2026, 3, 13, 11, 0))
        self._attendance(_utc(2026, 3, 13, 14, 0), _utc(2026, 3, 13, 16, 0))
        row = self._only_row(3, 2026)
        self.assertEqual(row["completionPercentage"], 50.0)

    def test_an_in_progress_day_counts_only_finished_sessions(self):
        """Matches `shift_duration`: the open session has no end yet."""
        self._day_schedule()
        self._attendance(_utc(2026, 3, 19, 9, 0), _utc(2026, 3, 19, 11, 0))
        self._attendance(_utc(2026, 3, 19, 12, 0))
        row = self._only_row(3, 2026)
        self.assertEqual(row["status"], "active")
        self.assertEqual(row["targetDuration"], "08h 00m")
        self.assertEqual(row["completionPercentage"], 25.0)

    def test_a_weekend_is_zero_with_non_working_day(self):
        """Saturday is not in the schedule: a zero target, no percentage, and
        a reason the app can render as "Weekend"."""
        self._day_schedule()
        self._attendance(_utc(2026, 3, 14, 10, 0), _utc(2026, 3, 14, 12, 0))
        row = self._only_row(3, 2026)
        self.assertIsNone(row["targetDuration"], "no target -> null, not 00h 00m")
        self.assertIsNone(row["completionPercentage"])
        self.assertEqual(row["targetReason"], "non_working_day")
        self.assertEqual(row["targetReasonMessage"],
                         "Not a working day in your schedule")

    def test_an_approved_leave_day_is_zero_with_time_off(self):
        """The reported case: a scheduled weekday wiped out by the employee's
        own approved leave -- and they still clocked in."""
        self._day_schedule()
        leave_type = self.env["hr.leave.type"].sudo().create({
            "name": "TP Auto Leave", "requires_allocation": False,
            "request_unit": "day", "leave_validation_type": "no_validation"})
        leave = self.env["hr.leave"].sudo().create({
            "employee_id": self.employee.id, "holiday_status_id": leave_type.id,
            "request_date_from": date(2026, 3, 11),
            "request_date_to": date(2026, 3, 11)})
        self.assertEqual(leave.state, "validate", "fixture: must be approved")
        self._attendance(_utc(2026, 3, 11, 9, 0), _utc(2026, 3, 11, 10, 0))
        row = self._only_row(3, 2026)
        self.assertIsNone(row["targetDuration"], "no target -> null, not 00h 00m")
        self.assertIsNone(row["completionPercentage"])
        self.assertEqual(row["targetReason"], "time_off")
        self.assertEqual(row["targetReasonMessage"], "On leave (TP Auto Leave)",
                         "the message names the leave type")

    def test_a_weekend_inside_a_leave_is_still_non_working_day(self):
        """A Friday-to-Monday leave covers Saturday's DATE, but Saturday had
        no scheduled hours to take off: it is a weekend, not time off."""
        self._day_schedule()
        leave_type = self.env["hr.leave.type"].sudo().create({
            "name": "TP Auto Leave 2", "requires_allocation": False,
            "request_unit": "day", "leave_validation_type": "no_validation"})
        self.env["hr.leave"].sudo().create({
            "employee_id": self.employee.id, "holiday_status_id": leave_type.id,
            "request_date_from": date(2026, 3, 13),
            "request_date_to": date(2026, 3, 16)})
        self._attendance(_utc(2026, 3, 14, 10, 0), _utc(2026, 3, 14, 11, 0))
        row = self._only_row(3, 2026)
        self.assertEqual(row["targetReason"], "non_working_day")
        self.assertEqual(row["targetReasonMessage"],
                         "Not a working day in your schedule",
                         "a weekend inside a leave is still a weekend")

    def test_a_failed_calculation_stays_null_not_zero(self):
        """"Could not compute" must not masquerade as a zero target with a
        reason -- all three keys stay null."""
        self._day_schedule()
        self._attendance(_utc(2026, 3, 12, 9, 0), _utc(2026, 3, 12, 10, 0))
        with patch.object(type(self.env["hr.employee"]),
                          "_get_expected_attendances",
                          side_effect=RuntimeError("calendar engine down")):
            row = self._only_row(3, 2026)
        self.assertIsNone(row["targetDuration"])
        self.assertIsNone(row["completionPercentage"])
        self.assertIsNone(row["targetReason"])
        self.assertIsNone(row["targetReasonMessage"])

    def test_a_public_holiday_is_zero_with_non_working_day(self):
        """Scheduled hours removed by a company-wide closure are not the
        employee's time off."""
        calendar = self._day_schedule()
        self.env["resource.calendar.leaves"].sudo().create({
            "name": "TP Holiday", "calendar_id": calendar.id,
            "company_id": self.employee.company_id.id, "resource_id": False,
            "time_type": "leave",
            "date_from": _utc(2026, 3, 12, 0, 0),
            "date_to": _utc(2026, 3, 12, 23, 59)})
        self._attendance(_utc(2026, 3, 12, 9, 0), _utc(2026, 3, 12, 10, 0))
        row = self._only_row(3, 2026)
        self.assertIsNone(row["targetDuration"], "no target -> null, not 00h 00m")
        self.assertIsNone(row["completionPercentage"])
        self.assertEqual(row["targetReason"], "non_working_day",
                         "a closure is not the employee's own time off")
        self.assertEqual(row["targetReasonMessage"], "Public holiday (TP Holiday)")

    def test_a_fully_flexible_employee_is_zero_with_no_schedule(self):
        """No schedule at all. Odoo would report the whole window as working
        time, so without the guard every target would read 24h."""
        self.employee.sudo().write({"resource_calendar_id": False})
        self._attendance(_utc(2026, 3, 12, 9, 0), _utc(2026, 3, 12, 17, 0))
        row = self._only_row(3, 2026)
        self.assertIsNone(row["targetDuration"], "no target -> null, not 00h 00m")
        self.assertIsNone(row["completionPercentage"])
        self.assertEqual(row["targetReason"], "no_schedule")
        self.assertEqual(row["targetReasonMessage"], "No working schedule assigned")

    def test_a_night_shifts_target_is_split_by_midnight(self):
        """Monday 22:00 to Tuesday 04:00: the target only counts schedule inside each day's calendar window.
        So Monday reads 300% complete and Tuesday keeps a 4h target nothing was worked against.
        """
        self._schedule("TP Night 6h", [("0", 22, 24, "afternoon"),
                                       ("1", 0, 4, "morning")])
        self._attendance(_utc(2026, 3, 16, 22, 0), _utc(2026, 3, 17, 4, 0))
        row = self._only_row(3, 2026)
        self.assertEqual(row["work_date"], "2026-03-16")
        self.assertEqual(row["targetDuration"], "02h 00m")
        self.assertEqual(row["completionPercentage"], 300.0)

    def test_the_target_follows_the_employees_own_schedule(self):
        """Not a hardcoded 8h: a 4h-a-day schedule gives a 4h target."""
        self._schedule("TP Half 4h", [(d, 9, 13, "morning") for d in "01234"])
        self._attendance(_utc(2026, 3, 12, 9, 0), _utc(2026, 3, 12, 11, 0))
        row = self._only_row(3, 2026)
        self.assertEqual(row["targetDuration"], "04h 00m")
        self.assertEqual(row["completionPercentage"], 50.0)

    def test_the_session_shape_does_not_grow_the_new_keys(self):
        """`group=session` is the frozen pre-grouping shape for older builds."""
        self._day_schedule()
        self._attendance(_utc(2026, 3, 12, 9, 0), _utc(2026, 3, 12, 17, 0))
        row = self._logs(group="session")["logs"][0]
        self.assertNotIn("targetDuration", row)
        self.assertNotIn("completionPercentage", row)
        self.assertNotIn("targetReason", row)
        self.assertNotIn("targetReasonMessage", row)
        self.assertNotIn("plannedShifts", row)

    def test_no_shift_means_an_empty_planned_shifts_list(self):
        """Without Planning (or without a published shift) every grouped row
        carries `plannedShifts: []`."""
        self._night_shift()
        rows = self._logs()["logs"]
        self.assertTrue(all(r["plannedShifts"] == [] for r in rows), rows)
        self.assertEqual([r["work_date"] for r in rows],
                         ["2026-03-10", "2026-03-09"])

    def test_group_session_returns_one_row_per_record(self):
        """`group=session` keeps the older per-record shape, including the date range for an overnight shift."""
        self._night_shift()
        data = self._logs(group="session")
        self.assertEqual(len(data["logs"]), 2)
        self.assertEqual(data["pagination"]["total"], 2)
        dates = [r["date"] for r in data["logs"]]
        self.assertIn("March 9-10, 2026", dates)
        self.assertNotIn("work_date", data["logs"][0],
                         "the session shape must not grow grouped keys")
        self.assertNotIn("session_count", data["logs"][0])


@tagged("-at_install", "post_install")
class TestAttendanceMultipleSessionsPerDay(HttpCase):
    """`POST /attendance/action` allows more than one session in a work day (stepping out and back).
    Uses the real endpoint because the guard lives only there.
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        config = cls.env["mobile.config"].sudo().search([], limit=1)
        if not config:
            config = cls.env["mobile.config"].sudo().create({})
        # GPS off: this class is about the session-count rule, not the fence.
        config.write({"attendance_gps_required": False})

        cls.user = Users.create({
            "name": "Multi Session User",
            "login": "multi_session_user@test.com",
            "password": PASSWORD,
            "tz": TZ,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Multi Session User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })

    def _token(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": "multi_session_user@test.com", "password": PASSWORD},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"]

    def _action(self, action, token):
        resp = self.url_open(
            "/api/mobile/v1/attendance/action",
            json={"action": action},
            headers={"Authorization": "Bearer %s" % token,
                     "Content-Type": "application/json"},
        )
        return resp.status_code, resp.json()

    def _sequence(self, actions, token):
        """Run *actions*, each five minutes after the last.
        Datetime.now() truncates to seconds, so back-to-back requests would otherwise share one timestamp.
        """
        base = fields.Datetime.now()
        results = []
        for index, action in enumerate(actions):
            stamp = base + timedelta(minutes=5 * index)
            with patch.object(fields.Datetime, "now", staticmethod(lambda s=stamp: s)):
                results.append(self._action(action, token))
        return results

    def test_a_second_session_in_the_same_day_is_accepted(self):
        token = self._token()
        results = self._sequence(
            ["check_in", "check_out", "check_in", "check_out"], token)

        # The third step is the one a per-day cap would refuse.
        for index, (status, body) in enumerate(results):
            self.assertEqual(status, 200, "action %s: %s" % (index, body))
            self.assertNotEqual(body.get("code"), "already_completed_today")

        attendances = self.env["hr.attendance"].sudo().search(
            [("employee_id", "=", self.employee.id)])
        self.assertEqual(len(attendances), 2,
                         "both sessions should have been recorded")

    def test_both_sessions_appear_under_one_work_day(self):
        """End to end: two sessions created through the API collapse into a
        single grouped row carrying four events."""
        token = self._token()
        for status, body in self._sequence(
                ["check_in", "check_out", "check_in", "check_out"], token):
            self.assertEqual(status, 200, body)

        resp = self.url_open(
            "/api/mobile/v1/attendance/logs?page=1&limit=50",
            headers={"Authorization": "Bearer %s" % token})
        data = resp.json()["data"]
        self.assertEqual(len(data["logs"]), 1, data["logs"])
        row = data["logs"][0]
        self.assertEqual(row["session_count"], 2)
        self.assertEqual([s["type"] for s in row["sessions"]],
                         ["check_in", "check_out", "check_in", "check_out"])

    def test_a_double_check_in_never_opens_a_second_session(self):
        """A repeat check-in is replayed (200, `already_recorded`) and never opens a second session."""
        token = self._token()
        status, body = self._action("check_in", token)
        self.assertEqual(status, 200, body)
        first_id = body["data"]["attendance"]["id"]
        status, body = self._action("check_in", token)
        self.assertEqual(status, 200, body)
        self.assertTrue(body["data"]["already_recorded"])
        self.assertEqual(body["data"]["attendance"]["id"], first_id)
        self.assertEqual(
            self.env["hr.attendance"].sudo().search_count([
                ("employee_id", "=", self.employee.id),
                ("check_out", "=", False)]),
            1)

    def test_a_check_out_without_a_check_in_is_still_refused(self):
        token = self._token()
        status, body = self._action("check_out", token)
        self.assertEqual(status, 409, body)
        self.assertEqual(body["code"], "not_checked_in")
