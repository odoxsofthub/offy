from datetime import date
from unittest import SkipTest
from unittest.mock import patch

from odoo.tests import HttpCase, tagged

from ..controllers.attendance import MobileApiAttendance
from .test_attendance_work_day_grouping import TZ, _utc

PASSWORD = "planned_shift_pw_1234"
LOGIN = "planned_shift_user@test.com"


@tagged("-at_install", "post_install")
class TestAttendancePlannedShifts(HttpCase):
    """`/attendance/logs` groups by a published Planning shift, e.g. one overnight shift with a break.
    Skips itself when the optional Enterprise Planning app is not installed."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        if "planning.slot" not in cls.env:
            raise SkipTest("Planning is not installed; shift grouping is inactive.")
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        config = cls.env["mobile.config"].sudo().search([], limit=1)
        if not config:
            config = cls.env["mobile.config"].sudo().create({})

        # Plain internal user (not Planning): own published shifts must read via Planning's record rule.
        cls.user = cls.env["res.users"].sudo().create({
            "name": "Planned Shift User",
            "login": LOGIN,
            "password": PASSWORD,
            "tz": TZ,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = cls.env["hr.employee"].sudo().create({
            "name": "Planned Shift User",
            "company_id": company.id,
            "user_id": cls.user.id,
            "tz": TZ,
        })
        cls.other_employee = cls.env["hr.employee"].sudo().create({
            "name": "Someone Else", "company_id": company.id, "tz": TZ})

    def _attendance(self, check_in, check_out=None):
        return self.env["hr.attendance"].sudo().create({
            "employee_id": self.employee.id,
            "check_in": check_in,
            "check_out": check_out,
        })

    def _shift(self, start, end, state="published", employee=None, **values):
        return self.env["planning.slot"].sudo().create(dict(values, **{
            "resource_id": (employee or self.employee).resource_id.id,
            "start_datetime": start,
            "end_datetime": end,
            "state": state,
        }))

    def _night_shift(self, state="published"):
        """Mon 9 March 20:00 -> Tue 10 March 08:00, worked with a break."""
        shift = self._shift(_utc(2026, 3, 9, 20, 0), _utc(2026, 3, 10, 8, 0),
                            state=state)
        self._attendance(_utc(2026, 3, 9, 20, 0), _utc(2026, 3, 10, 2, 0))
        self._attendance(_utc(2026, 3, 10, 6, 0), _utc(2026, 3, 10, 8, 0))
        return shift

    def _logs(self, month=3, year=2026):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": LOGIN, "password": PASSWORD},
            headers={"Content-Type": "application/json"},
        )
        token = resp.json()["data"]["token"]
        resp = self.url_open(
            "/api/mobile/v1/attendance/logs?month=%s&year=%s&limit=50" % (month, year),
            headers={"Authorization": "Bearer %s" % token})
        body = resp.json()
        self.assertEqual(resp.status_code, 200, body)
        self.assertTrue(body["success"], body)
        return body["data"]["logs"]

    def _day_schedule(self):
        """Mon-Fri 09:00-17:00, so a weekend day has no scheduled hours."""
        calendar = self.env["resource.calendar"].sudo().create({
            "name": "PS Day", "tz": TZ,
            "attendance_ids": [(5, 0, 0)] + [(0, 0, {
                "name": "PS %s" % weekday, "dayofweek": weekday,
                "hour_from": 9, "hour_to": 17, "day_period": "morning",
            }) for weekday in "01234"],
        })
        self.employee.sudo().resource_calendar_id = calendar

    def test_a_published_night_shift_with_a_break_is_one_row(self):
        self._night_shift()
        logs = self._logs()
        self.assertEqual(len(logs), 1, "the shift was split: %s" % logs)
        row = logs[0]
        self.assertEqual(row["work_date"], "2026-03-09")
        self.assertEqual(row["date"], "March 9-10, 2026")
        self.assertEqual(row["session_count"], 2)
        self.assertEqual(row["shift_duration"], "08h 00m")
        self.assertEqual(row["time_info"], "8:00 PM - 8:00 AM")

    def test_without_planning_the_same_night_is_split_by_the_cutover(self):
        """The fallback: exactly today's flow when Planning is absent."""
        self._night_shift()
        with patch.object(MobileApiAttendance, "_planning_installed",
                          lambda self: False):
            logs = self._logs()
        self.assertEqual([r["work_date"] for r in logs],
                         ["2026-03-10", "2026-03-09"])
        self.assertTrue(all(r["plannedShifts"] == [] for r in logs))

    def test_a_draft_shift_is_ignored(self):
        """Even for a Planning MANAGER, who -- unlike a plain employee -- can
        read drafts, so only the API's own filter keeps them out."""
        self.user.sudo().group_ids = [
            (4, self.env.ref("planning.group_planning_manager").id)]
        self._night_shift(state="draft")
        logs = self._logs()
        self.assertEqual(len(logs), 2, "a draft shift must not group rows")
        self.assertTrue(all(r["plannedShifts"] == [] for r in logs))

    def test_another_employees_shift_is_ignored(self):
        self._shift(_utc(2026, 3, 9, 20, 0), _utc(2026, 3, 10, 8, 0),
                    employee=self.other_employee)
        self._attendance(_utc(2026, 3, 9, 20, 0), _utc(2026, 3, 10, 2, 0))
        self._attendance(_utc(2026, 3, 10, 6, 0), _utc(2026, 3, 10, 8, 0))
        self.assertEqual(len(self._logs()), 2)

    def test_an_early_check_in_within_two_hours_joins_the_shift(self):
        """An early check-in within two hours of the shift is filed under the shift's own day."""
        self._shift(_utc(2026, 3, 10, 6, 0), _utc(2026, 3, 10, 14, 0))
        self._attendance(_utc(2026, 3, 10, 4, 30), _utc(2026, 3, 10, 10, 0))
        self._attendance(_utc(2026, 3, 10, 10, 30), _utc(2026, 3, 10, 14, 0))
        logs = self._logs()
        self.assertEqual(len(logs), 1, logs)
        self.assertEqual(logs[0]["work_date"], "2026-03-10")
        self.assertEqual(logs[0]["shift_status"], "On-Time")

    def test_a_check_in_more_than_two_hours_early_is_not_the_shifts(self):
        """A check-in 2.5h early is not the shift's, but joins its row as a second session."""
        shift = self._shift(_utc(2026, 3, 10, 6, 0), _utc(2026, 3, 10, 14, 0))
        # Allocated Time stated outright: this test is about grouping, not
        # about what Odoo would allocate against the default schedule.
        shift.sudo().allocated_hours = 8.0
        shift.sudo().flush_recordset()
        self._attendance(_utc(2026, 3, 10, 3, 30), _utc(2026, 3, 10, 4, 0))
        self._attendance(_utc(2026, 3, 10, 6, 0), _utc(2026, 3, 10, 14, 0))
        logs = self._logs()
        self.assertEqual([r["work_date"] for r in logs], ["2026-03-10"])
        self.assertEqual(logs[0]["session_count"], 2)
        self.assertEqual(logs[0]["targetDuration"], "08h 00m")

    def test_late_is_judged_against_the_shift_start(self):
        self._shift(_utc(2026, 3, 9, 20, 0), _utc(2026, 3, 10, 8, 0))
        self._attendance(_utc(2026, 3, 9, 20, 30), _utc(2026, 3, 10, 8, 0))
        self.assertEqual(self._logs()[0]["shift_status"], "Late")

    def test_a_shift_across_the_month_end_stays_in_its_month(self):
        """31 March 20:00 -> 1 April 08:00: the 06:00 session on the 1st is
        March's, and April does not show it."""
        self._shift(_utc(2026, 3, 31, 20, 0), _utc(2026, 4, 1, 8, 0))
        self._attendance(_utc(2026, 3, 31, 20, 0), _utc(2026, 3, 31, 23, 0))
        self._attendance(_utc(2026, 4, 1, 6, 0), _utc(2026, 4, 1, 8, 0))
        march = self._logs(3, 2026)
        self.assertEqual(len(march), 1)
        self.assertEqual(march[0]["session_count"], 2)
        self.assertEqual(march[0]["date"], "March 31-April 1, 2026")
        self.assertEqual(self._logs(4, 2026), [])

    def test_the_target_is_the_shift_length(self):
        """With 0h allocated (shift outside the schedule), the target falls back to the shift length."""
        shift = self._night_shift()
        shift.flush_recordset()
        self.assertEqual(shift.allocated_hours, 0.0,
                         "fixture: this is the fallback case")
        row = self._logs()[0]
        self.assertEqual(row["targetDuration"], "12h 00m")
        self.assertEqual(row["completionPercentage"], 66.7)   # 8h of 12h
        self.assertIsNone(row["targetReason"])
        self.assertIsNone(row["targetReasonMessage"])

    def test_an_untouched_shift_targets_allocated_time_not_its_window(self):
        """An unedited shift targets Odoo's Allocated Time (schedule overlap), not the shift window."""
        calendar = self.env["resource.calendar"].sudo().create({
            "name": "PS Late Start", "tz": TZ,
            "attendance_ids": [(5, 0, 0)] + [
                (0, 0, {"name": "PS %s %s" % (weekday, period), "dayofweek": weekday,
                        "hour_from": start, "hour_to": end, "day_period": period})
                for weekday in "01234"
                for start, end, period in ((10, 13, "morning"), (13, 14, "lunch"),
                                           (14, 19, "afternoon"))],
        })
        self.employee.sudo().resource_calendar_id = calendar
        shift = self._shift(_utc(2026, 3, 10, 9, 0), _utc(2026, 3, 10, 19, 0))
        shift.flush_recordset()
        self.assertEqual(shift.allocated_hours, 8.0,
                         "fixture: Odoo's own allocation, untouched")
        self.assertEqual(shift.allocated_percentage, 100.0)
        self._attendance(_utc(2026, 3, 10, 9, 0), _utc(2026, 3, 10, 13, 0))

        row = self._logs()[0]
        self.assertEqual(row["targetDuration"], "08h 00m")
        self.assertEqual(row["completionPercentage"], 50.0)   # 4h of 8h
        self.assertEqual(row["plannedShifts"][0]["duration"], "08h 00m",
                         "the shift's own duration must match the row target")

    def test_a_zero_percent_shift_defers_to_the_schedule(self):
        """0% is the planner saying the shift does not count, which is not the
        same as Odoo failing to allocate it -- so no fallback to the window."""
        self._day_schedule()
        shift = self._shift(_utc(2026, 3, 11, 9, 0), _utc(2026, 3, 11, 17, 0))
        shift.sudo().allocated_percentage = 0.0
        shift.sudo().flush_recordset()
        self.assertEqual(shift.allocated_hours, 0.0)
        self._attendance(_utc(2026, 3, 11, 9, 0), _utc(2026, 3, 11, 13, 0))
        # The Mon-Fri 09:00-17:00 schedule's 8h, not the shift's.
        self.assertEqual(self._logs()[0]["targetDuration"], "08h 00m")

    def test_allocated_time_set_by_the_planner_is_the_target(self):
        """Planner-set allocated hours are the target; the stored percentage is against the schedule overlap."""
        self._day_schedule()
        shift = self._shift(_utc(2026, 3, 11, 12, 0), _utc(2026, 3, 11, 21, 0))
        shift.sudo().allocated_hours = 8.0
        shift.sudo().flush_recordset()
        self.assertGreater(shift.allocated_percentage, 100,
                           "fixture: this is the case that used to inflate")
        self._attendance(_utc(2026, 3, 11, 12, 0), _utc(2026, 3, 11, 16, 0))
        row = self._logs()[0]
        self.assertEqual(row["targetDuration"], "08h 00m")
        self.assertEqual(row["completionPercentage"], 50.0)
        self.assertEqual(row["plannedShifts"][0]["duration"], "08h 00m")

    def test_a_half_allocated_shift_halves_the_target(self):
        """Allocated Time 04:00 on an 8h shift."""
        self._day_schedule()
        shift = self._shift(_utc(2026, 3, 11, 9, 0), _utc(2026, 3, 11, 17, 0))
        shift.sudo().allocated_hours = 4.0
        shift.sudo().flush_recordset()
        self._attendance(_utc(2026, 3, 11, 9, 0), _utc(2026, 3, 11, 13, 0))
        self.assertEqual(self._logs()[0]["targetDuration"], "04h 00m")

    def test_a_shift_on_a_weekend_wins_over_the_schedule(self):
        """Saturday 14 March has no scheduled hours; the shift is the target."""
        self._day_schedule()
        self._shift(_utc(2026, 3, 14, 10, 0), _utc(2026, 3, 14, 14, 0))
        self._attendance(_utc(2026, 3, 14, 10, 0), _utc(2026, 3, 14, 12, 0))
        row = self._logs()[0]
        self.assertEqual(row["targetDuration"], "04h 00m")
        self.assertEqual(row["completionPercentage"], 50.0)
        self.assertIsNone(row["targetReason"])

    def test_a_shift_wins_over_approved_leave(self):
        self._day_schedule()
        leave_type = self.env["hr.leave.type"].sudo().create({
            "name": "PS Auto Leave", "requires_allocation": False,
            "request_unit": "day", "leave_validation_type": "no_validation"})
        self.env["hr.leave"].sudo().create({
            "employee_id": self.employee.id, "holiday_status_id": leave_type.id,
            "request_date_from": date(2026, 3, 11),
            "request_date_to": date(2026, 3, 11)})
        self._shift(_utc(2026, 3, 11, 9, 0), _utc(2026, 3, 11, 17, 0))
        self._attendance(_utc(2026, 3, 11, 9, 0), _utc(2026, 3, 11, 13, 0))
        row = self._logs()[0]
        self.assertEqual(row["targetDuration"], "08h 00m")
        self.assertIsNone(row["targetReason"])

    def test_a_day_without_a_shift_keeps_the_schedule_target(self):
        self._day_schedule()
        self._night_shift()
        self._attendance(_utc(2026, 3, 12, 9, 0), _utc(2026, 3, 12, 13, 0))
        row = next(r for r in self._logs() if r["work_date"] == "2026-03-12")
        self.assertEqual(row["targetDuration"], "08h 00m")
        self.assertEqual(row["plannedShifts"], [])

    def test_planned_shifts_describe_the_shift(self):
        role = self.env["planning.role"].sudo().create({"name": "PS Night Guard"})
        self._shift(_utc(2026, 3, 9, 20, 0), _utc(2026, 3, 10, 8, 0),
                    role_id=role.id)
        self._attendance(_utc(2026, 3, 9, 20, 0), _utc(2026, 3, 10, 8, 0))
        self.assertEqual(self._logs()[0]["plannedShifts"], [{
            "date": "March 9-10, 2026",
            "time_info": "8:00 PM - 8:00 AM",
            "start": "2026-03-09T14:30:00Z",
            "end": "2026-03-10T02:30:00Z",
            "duration": "12h 00m",
            "role": "PS Night Guard",
        }])
