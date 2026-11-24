from datetime import datetime

from odoo.tests import HttpCase, tagged

PASSWORD = "attendance_paging_pw_1234"
LOGIN = "attendance_paging_user@test.com"


@tagged("-at_install", "post_install")
class TestAttendanceLogsPagination(HttpCase):
    """`/attendance/logs` paginates in the query while averages and total stay period-wide.
    Fixture: Aug 1-5 UTC shifts of 2h-6h; page 2 of limit 2 has averages that differ from the period's."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        company = cls.env.ref("base.main_company")

        cls.user = Users.create({
            "name": "Attendance Paging User",
            "login": LOGIN,
            "password": PASSWORD,
            "tz": "UTC",
            "group_ids": [(4, mobile_group.id),
                          (4, cls.env.ref("base.group_user").id)],
        })
        cls.employee = Employee.create({
            "name": "Attendance Paging User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })
        for day, start_hour, end_hour in [
            (1, 6, 8), (2, 7, 10), (3, 8, 12), (4, 9, 14), (5, 10, 16),
        ]:
            cls.env["hr.attendance"].sudo().create({
                "employee_id": cls.employee.id,
                "check_in": datetime(2026, 8, day, start_hour, 0, 0),
                "check_out": datetime(2026, 8, day, end_hour, 0, 0),
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

    def _logs(self, page, limit):
        resp = self.url_open(
            "/api/mobile/v1/attendance/logs?month=8&year=2026&page=%s&limit=%s"
            % (page, limit),
            headers={"Authorization": "Bearer %s" % self._token()},
        )
        body = resp.json()
        self.assertEqual(resp.status_code, 200, body)
        self.assertTrue(body["success"], body)
        return body["data"]

    def test_first_page_returns_the_newest_rows(self):
        data = self._logs(page=1, limit=2)
        self.assertEqual(
            [log["date"] for log in data["logs"]],
            ["August 5, 2026", "August 4, 2026"])
        self.assertEqual(data["pagination"]["total"], 5)
        self.assertTrue(data["pagination"]["has_next"])

    def test_middle_page_continues_where_the_first_ended(self):
        data = self._logs(page=2, limit=2)
        self.assertEqual(
            [log["date"] for log in data["logs"]],
            ["August 3, 2026", "August 2, 2026"])
        self.assertEqual(data["pagination"]["total"], 5)
        self.assertTrue(data["pagination"]["has_next"])

    def test_last_page_reports_no_next(self):
        data = self._logs(page=3, limit=2)
        self.assertEqual([log["date"] for log in data["logs"]],
                         ["August 1, 2026"])
        self.assertEqual(data["pagination"]["total"], 5)
        self.assertFalse(data["pagination"]["has_next"])

    def test_page_past_the_end_is_empty_but_still_counts_the_period(self):
        data = self._logs(page=9, limit=2)
        self.assertEqual(data["logs"], [])
        self.assertEqual(data["pagination"]["total"], 5)
        self.assertFalse(data["pagination"]["has_next"])

    def test_averages_are_period_wide_on_the_first_page(self):
        data = self._logs(page=1, limit=2)
        self.assertEqual(data["avg_in_time"], "8:00 AM")
        self.assertEqual(data["avg_worked_hour"], "04h 00m")

    def test_averages_do_not_narrow_to_the_requested_page(self):
        """Page 2's own rows average 7:30 AM / 03h 30m -- if either of those
        appears here, the averages have been scoped to the page."""
        data = self._logs(page=2, limit=2)
        self.assertEqual(data["avg_in_time"], "8:00 AM")
        self.assertEqual(data["avg_worked_hour"], "04h 00m")

    def test_averages_survive_a_page_past_the_end(self):
        """The emptiest possible page still describes the whole period."""
        data = self._logs(page=9, limit=2)
        self.assertEqual(data["avg_in_time"], "8:00 AM")
        self.assertEqual(data["avg_worked_hour"], "04h 00m")

    def test_an_open_shift_counts_for_check_in_but_not_for_hours(self):
        """No check-out means no duration to average, but the check-in is
        still a check-in -- the two averages have different populations."""
        self.env["hr.attendance"].sudo().create({
            "employee_id": self.employee.id,
            "check_in": datetime(2026, 8, 6, 14, 0, 0),
        })
        data = self._logs(page=1, limit=2)
        self.assertEqual(data["pagination"]["total"], 6)
        # check-ins 6,7,8,9,10,14 -> 9:00; worked hours unchanged at 4h.
        self.assertEqual(data["avg_in_time"], "9:00 AM")
        self.assertEqual(data["avg_worked_hour"], "04h 00m")
