from datetime import datetime

from odoo.tests import HttpCase, tagged

PASSWORD = "attendance_date_range_pw_1234"
LOGIN = "attendance_date_range_user@test.com"


@tagged("-at_install", "post_install")
class TestAttendanceDateRange(HttpCase):
    """`/attendance/logs` `date` for overnight shifts must span check-in to check-out day.
    Fixtures and mobile tz are UTC, and all tests use `group=session` (see `_logs_for`)."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        company = cls.env.ref("base.main_company")

        cls.user = Users.create({
            "name": "Attendance Date Range User",
            "login": LOGIN,
            "password": PASSWORD,
            "tz": "UTC",
            "group_ids": [(4, mobile_group.id), (4, cls.env.ref("base.group_user").id)],
        })
        cls.employee = Employee.create({
            "name": "Attendance Date Range User",
            "company_id": company.id,
            "user_id": cls.user.id,
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

    def _attendance(self, check_in, check_out=None):
        return self.env["hr.attendance"].sudo().create({
            "employee_id": self.employee.id,
            "check_in": check_in,
            "check_out": check_out,
        })

    def _logs_for(self, month, year):
        """Fetch logs with `group=session`, where the per-record `_date_range_display` applies.
        Grouped-mode labelling is covered by `test_attendance_work_day_grouping.py`."""
        token = self._token()
        resp = self.url_open(
            "/api/mobile/v1/attendance/logs"
            "?month=%s&year=%s&page=1&limit=50&group=session"
            % (month, year),
            headers={"Authorization": "Bearer %s" % token},
        )
        body = resp.json()
        self.assertEqual(resp.status_code, 200, body)
        self.assertTrue(body["success"], body)
        return body["data"]["logs"]

    def _date_for(self, month, year):
        logs = self._logs_for(month, year)
        self.assertEqual(len(logs), 1, "expected exactly one log row: %s" % logs)
        return logs[0]["date"]

    def test_overnight_shift_within_one_month_shows_both_days(self):
        self._attendance(
            datetime(2026, 8, 12, 4, 54, 47), datetime(2026, 8, 13, 12, 12, 13))
        self.assertEqual(self._date_for(8, 2026), "August 12-13, 2026")

    def test_shift_crossing_a_month_boundary_names_both_months(self):
        self._attendance(
            datetime(2026, 8, 31, 13, 43, 10), datetime(2026, 9, 1, 10, 56, 34))
        self.assertEqual(
            self._date_for(8, 2026), "August 31-September 1, 2026")

    def test_shift_crossing_a_year_boundary_names_both_years(self):
        self._attendance(
            datetime(2026, 12, 31, 22, 0, 0), datetime(2027, 1, 1, 6, 0, 0))
        self.assertEqual(
            self._date_for(12, 2026),
            "December 31, 2026-January 1, 2027")

    def test_year_boundary_gap_that_is_not_a_single_overnight_shift(self):
        """A multi-day span across a year boundary formats like a one-day overnight shift."""
        self._attendance(
            datetime(2026, 12, 31, 22, 0, 0), datetime(2027, 1, 5, 9, 0, 0))
        self.assertEqual(
            self._date_for(12, 2026),
            "December 31, 2026-January 5, 2027")

    def test_multi_month_gap_within_one_year(self):
        self._attendance(
            datetime(2026, 3, 1, 8, 0, 0), datetime(2026, 6, 15, 17, 0, 0))
        self.assertEqual(
            self._date_for(3, 2026),
            "March 1-June 15, 2026")

    def test_same_day_shift_is_unchanged(self):
        self._attendance(
            datetime(2026, 8, 31, 12, 50, 6), datetime(2026, 8, 31, 13, 43, 51))
        self.assertEqual(self._date_for(8, 2026), "August 31, 2026")

    def test_in_progress_shift_shows_only_the_check_in_day(self):
        """No check-out yet -- nothing to form a range with."""
        self._attendance(datetime(2026, 9, 2, 6, 7, 51))
        logs = self._logs_for(9, 2026)
        self.assertEqual(len(logs), 1)
        self.assertEqual(logs[0]["date"], "September 2, 2026")
        self.assertEqual(logs[0]["status"], "active")
