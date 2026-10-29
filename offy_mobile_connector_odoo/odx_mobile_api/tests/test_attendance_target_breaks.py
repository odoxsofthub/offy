from datetime import date
from unittest import SkipTest

from odoo.tests import HttpCase, tagged

from .test_attendance_work_day_grouping import TZ, _utc

PASSWORD = "target_breaks_pw_1234"
LOGIN = "target_breaks_user@test.com"

# Week of Monday 9 March 2026; Saturday 14 March is not a schedule day.
MON, TUE, WED, SAT = 9, 10, 11, 14


class _TargetCase(HttpCase):
    """Shared fixture: one mobile user and helpers for `/attendance/logs`."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")
        if not cls.env["mobile.config"].sudo().search([], limit=1):
            cls.env["mobile.config"].sudo().create({})
        cls.user = cls.env["res.users"].sudo().create({
            "name": "Target Breaks User", "login": LOGIN, "password": PASSWORD,
            "tz": TZ,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = cls.env["hr.employee"].sudo().create({
            "name": "Target Breaks User", "company_id": company.id,
            "user_id": cls.user.id, "tz": TZ,
        })

    def _schedule(self, lines, **values):
        """A Mon-Fri schedule from ``(day_period, hour_from, hour_to)``."""
        calendar = self.env["resource.calendar"].sudo().create(dict({
            "name": "TB Schedule", "tz": TZ,
            "attendance_ids": [(5, 0, 0)] + [(0, 0, {
                "name": "TB %s %s" % (weekday, period), "dayofweek": weekday,
                "day_period": period, "hour_from": hour_from, "hour_to": hour_to,
            }) for weekday in "01234" for period, hour_from, hour_to in lines],
        }, **values))
        self.employee.sudo().resource_calendar_id = calendar
        return calendar

    def _with_lunch(self):
        """08:00-12:00, lunch 12:00-13:00, 13:00-17:00 -- 8h a day."""
        return self._schedule([("morning", 8, 12), ("lunch", 12, 13),
                               ("afternoon", 13, 17)])

    def _flexible(self):
        calendar = self.env["resource.calendar"].sudo().create({
            "name": "TB Flexible", "tz": TZ, "flexible_hours": True,
            "hours_per_day": 8.0, "full_time_required_hours": 40.0,
            "attendance_ids": [(5, 0, 0)],
        })
        self.employee.sudo().resource_calendar_id = calendar
        return calendar

    def _attendance(self, day, hour_from=9, hour_to=11):
        return self.env["hr.attendance"].sudo().create({
            "employee_id": self.employee.id,
            "check_in": _utc(2026, 3, day, hour_from, 0),
            "check_out": _utc(2026, 3, day, hour_to, 0),
        })

    def _leave(self, day):
        leave_type = self.env["hr.leave.type"].sudo().create({
            "name": "TB Leave", "requires_allocation": False,
            "request_unit": "day", "leave_validation_type": "no_validation"})
        return self.env["hr.leave"].sudo().create({
            "employee_id": self.employee.id, "holiday_status_id": leave_type.id,
            "request_date_from": date(2026, 3, day),
            "request_date_to": date(2026, 3, day)})

    def _row(self, day):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": LOGIN, "password": PASSWORD},
            headers={"Content-Type": "application/json"})
        token = resp.json()["data"]["token"]
        resp = self.url_open(
            "/api/mobile/v1/attendance/logs?month=3&year=2026&limit=50",
            headers={"Authorization": "Bearer %s" % token})
        body = resp.json()
        self.assertEqual(resp.status_code, 200, body)
        work_date = "2026-03-%02d" % day
        rows = [r for r in body["data"]["logs"] if r["work_date"] == work_date]
        self.assertEqual(len(rows), 1, "no single row for %s: %s"
                         % (work_date, body["data"]["logs"]))
        return rows[0]


@tagged("-at_install", "post_install")
class TestTargetWithoutPlanner(_TargetCase):
    """The daily Target from the work schedule, breaks left out."""

    def test_schedule_break_is_excluded(self):
        self._with_lunch()
        self._attendance(MON)
        self.assertEqual(self._row(MON)["targetDuration"], "08h 00m")

    def test_schedule_without_a_break_line_counts_every_hour(self):
        self._schedule([("morning", 9, 18)])
        self._attendance(MON)
        self.assertEqual(self._row(MON)["targetDuration"], "09h 00m")

    def test_flexible_hours_target_is_hours_per_day(self):
        """A flexible schedule has no attendance lines, so the target is hours per day."""
        self._flexible()
        self._attendance(MON)
        row = self._row(MON)
        self.assertEqual(row["targetDuration"], "08h 00m")
        self.assertIsNone(row["targetReason"])

    def test_flexible_hours_weekend_is_not_a_working_day(self):
        self._flexible()
        self._attendance(SAT)
        row = self._row(SAT)
        self.assertEqual(row["targetReason"], "non_working_day")

    def test_flexible_hours_full_day_leave_is_time_off(self):
        self._flexible()
        self._leave(TUE)
        self._attendance(TUE)
        row = self._row(TUE)
        self.assertEqual(row["targetReason"], "time_off")
        self.assertIn("TB Leave", row["targetReasonMessage"])


@tagged("-at_install", "post_install")
class TestTargetWithPlanner(_TargetCase):
    """The daily Target from published Planning shifts, breaks left out."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        if "planning.slot" not in cls.env:
            raise SkipTest("Planning is not installed.")

    def _shift(self, day, hour_from, hour_to, **values):
        end_day = day + 1 if hour_to > 24 else day
        shift = self.env["planning.slot"].sudo().create(dict(values, **{
            "resource_id": self.employee.resource_id.id,
            "start_datetime": _utc(2026, 3, day, hour_from, 0),
            "end_datetime": _utc(2026, 3, end_day, hour_to % 24, 0),
            "state": "published",
        }))
        shift.flush_recordset()
        return shift

    def _target(self, day, hour_from, hour_to, **values):
        self._shift(day, hour_from, hour_to, **values)
        self._attendance(day, hour_from, hour_from + 2)
        row = self._row(day)
        self.assertIsNone(row["targetReason"])
        return row

    def test_shift_matching_the_schedule(self):
        self._with_lunch()
        self.assertEqual(self._target(MON, 8, 17)["targetDuration"], "08h 00m")

    def test_an_offset_shift_targets_what_planning_shows(self):
        """09:00-18:00 on an 08:00-17:00 schedule targets 7h, matching Planning's Allocated Time.
        When a Planning shift exists the app reflects what the planner sees; otherwise the schedule."""
        self._with_lunch()
        row = self._target(MON, 9, 18)
        self.assertEqual(row["targetDuration"], "07h 00m")
        self.assertEqual(row["plannedShifts"][0]["duration"], "07h 00m")

    def test_a_later_offset_shift_targets_what_planning_shows(self):
        """10:00-19:00 on an 08:00-17:00 schedule: Allocated Time 6h."""
        self._with_lunch()
        self.assertEqual(self._target(MON, 10, 19)["targetDuration"], "06h 00m")

    def test_a_typed_allocated_time_on_an_offset_shift_is_honoured(self):
        """The planner's override is how an offset shift gets its full hours:
        type 8h into Allocated Time and the app shows 8h."""
        self._with_lunch()
        row = self._target(MON, 9, 18, allocated_hours=8.0)
        self.assertEqual(row["targetDuration"], "08h 00m")

    def test_saturday_shift_takes_out_the_usual_break(self):
        """A non-schedule day still deducts the usual break."""
        self._with_lunch()
        self.assertEqual(self._target(SAT, 8, 17)["targetDuration"], "08h 00m")

    def test_shift_on_a_day_of_leave_takes_out_the_break(self):
        self._with_lunch()
        self._leave(WED)
        self.assertEqual(self._target(WED, 8, 17)["targetDuration"], "08h 00m")

    def test_two_shifts_around_the_break(self):
        self._with_lunch()
        self._shift(MON, 8, 12)
        self._shift(MON, 13, 17)
        self._attendance(MON, 8, 10)
        row = self._row(MON)
        self.assertEqual(row["targetDuration"], "08h 00m")
        self.assertEqual([s["duration"] for s in row["plannedShifts"]],
                         ["04h 00m", "04h 00m"])

    def test_night_shift_outside_the_break(self):
        self._with_lunch()
        self._shift(MON, 22, 30)
        self._attendance(MON, 22, 23)
        self.assertEqual(self._row(MON)["targetDuration"], "08h 00m")

    def test_allocated_time_typed_on_a_shift_outside_the_schedule(self):
        """No schedule overlap: Odoo keeps 100% even when the planner types."""
        self._with_lunch()
        shift = self._shift(SAT, 8, 17)
        shift.sudo().allocated_hours = 6.0
        shift.flush_recordset()
        self._attendance(SAT, 8, 10)
        self.assertEqual(self._row(SAT)["targetDuration"], "06h 00m")

    def test_allocated_time_typed_by_the_planner_is_kept(self):
        self._with_lunch()
        shift = self._shift(MON, 8, 17)
        shift.sudo().allocated_hours = 9.0
        shift.flush_recordset()
        self._attendance(MON, 8, 10)
        self.assertEqual(self._row(MON)["targetDuration"], "09h 00m")

    def test_half_allocated_shift(self):
        self._with_lunch()
        self.assertEqual(
            self._target(MON, 8, 17, allocated_percentage=50)["targetDuration"],
            "04h 00m")

    def test_employee_without_a_schedule_counts_the_whole_shift(self):
        """No schedule means no break is defined."""
        self.employee.sudo().resource_calendar_id = False
        self.assertEqual(self._target(MON, 8, 17)["targetDuration"], "09h 00m")

    def test_flexible_employee_keeps_plannings_allocated_time(self):
        self._flexible()
        self.assertEqual(self._target(MON, 8, 17)["targetDuration"], "08h 00m")
