from datetime import date, timedelta

from odoo.tests import HttpCase, tagged

PASSWORD = "tocal_pw_1234"
LOGIN = "tocal_user@test.com"


def _next_monday(base=None):
    """First Monday at least a week out -- keeps test dates on working days."""
    base = base or date.today()
    target = base + timedelta(days=7)
    return target + timedelta(days=(7 - target.weekday()) % 7)


@tagged("-at_install", "post_install")
class TestMobileTimeoffCalendarStates(HttpCase):
    """Which leave states mark a date in `/timeoff/calendar/*`.
    Refused and cancelled leaves are excluded: the employee is working that day."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        LeaveType = cls.env["hr.leave.type"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        base_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.user = Users.create({
            "name": "Timeoff Calendar User",
            "login": LOGIN,
            "password": PASSWORD,
            "group_ids": [(4, mobile_group.id), (4, base_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Timeoff Calendar User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })

        cls.leave_type = LeaveType.create({
            "name": "Cal Test Unpaid",
            "requires_allocation": False,
            "request_unit": "day",
            "leave_validation_type": "hr",
        })

        cls.day = _next_monday()

    def _make_leave(self, state, day=None, employee=None):
        """A leave forced into `state` via SQL, bypassing approver checks and allocation maths.
        Tests stack several leaves on one day, so Odoo's overlap check is skipped as hr_holidays does itself."""
        day = day or self.day
        leave = self.env["hr.leave"].sudo().with_context(leave_skip_date_check=True).create({
            "employee_id": (employee or self.employee).id,
            "holiday_status_id": self.leave_type.id,
            "request_date_from": day,
            "request_date_to": day,
        })
        self.env.cr.execute(
            "UPDATE hr_leave SET state = %s WHERE id = %s", [state, leave.id])
        self.env.invalidate_all()
        return leave

    def _token(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": LOGIN, "password": PASSWORD},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"]

    def _get(self, path):
        resp = self.url_open(
            path, headers={"Authorization": "Bearer %s" % self._token()})
        return resp.status_code, resp.json()

    def _month_day(self, day=None):
        """The month-grid cell for `day`."""
        day = day or self.day
        status, body = self._get(
            "/api/mobile/v1/timeoff/calendar/month?year=%d&month=%d"
            % (day.year, day.month))
        self.assertEqual(status, 200, body)
        return next(cell for cell in body["data"]["days"]
                    if cell["date"] == day.isoformat())

    def _day_items(self, day=None):
        day = day or self.day
        status, body = self._get(
            "/api/mobile/v1/timeoff/calendar/day?date=%s" % day.isoformat())
        self.assertEqual(status, 200, body)
        return body["data"]["items"]

    def test_refused_leave_does_not_mark_the_date(self):
        self._make_leave("refuse")
        cell = self._month_day()
        self.assertEqual(cell["leave_count"], 0)
        self.assertEqual(cell["statuses"], [])
        self.assertEqual(cell["types"], [])

    def test_refused_leave_is_absent_from_the_day_sheet(self):
        refused = self._make_leave("refuse")
        ids = [item["id"] for item in self._day_items()]
        self.assertNotIn(refused.id, ids)

    def test_refusing_an_approved_leave_clears_the_date(self):
        """The state transition, not just a record created refused."""
        leave = self._make_leave("validate")
        self.assertEqual(self._month_day()["leave_count"], 1)

        self.env.cr.execute(
            "UPDATE hr_leave SET state = 'refuse' WHERE id = %s", [leave.id])
        self.env.invalidate_all()
        self.assertEqual(self._month_day()["leave_count"], 0)

    def test_cancelled_leave_does_not_mark_the_date(self):
        """Same reasoning as `refuse` -- the employee works that day. Kept in
        the same suite so the two can never be fixed apart."""
        cancelled = self._make_leave("cancel")
        self.assertEqual(self._month_day()["leave_count"], 0)
        self.assertNotIn(cancelled.id,
                         [item["id"] for item in self._day_items()])

    def test_approved_leave_marks_the_date(self):
        self._make_leave("validate")
        cell = self._month_day()
        self.assertEqual(cell["leave_count"], 1)
        self.assertEqual(cell["statuses"], ["approved"])

    def test_pending_leave_still_marks_the_date(self):
        """A submitted request is an intended absence -- this calendar shows
        it so the employee can see what they asked for."""
        self._make_leave("confirm")
        cell = self._month_day()
        self.assertEqual(cell["leave_count"], 1)
        self.assertEqual(cell["statuses"], ["pending"])

    def test_first_approval_still_marks_the_date(self):
        self._make_leave("validate1")
        self.assertEqual(self._month_day()["statuses"],
                         ["pending_second_approval"])

    def test_a_refused_leave_does_not_inflate_the_count(self):
        """Two leaves on one date, one refused: the badge must not read 2."""
        self._make_leave("validate")
        self._make_leave("refuse")
        self.assertEqual(self._month_day()["leave_count"], 1)

    def test_month_count_matches_the_day_sheet(self):
        """Month count and day sheet share `_calendar_leave_domain` and must agree."""
        self._make_leave("validate")
        self._make_leave("confirm")
        self._make_leave("refuse")
        self._make_leave("cancel")

        self.assertEqual(self._month_day()["leave_count"],
                         len(self._day_items()))

    def test_a_day_with_only_refused_leave_is_empty_everywhere(self):
        self._make_leave("refuse")
        self._make_leave("cancel")
        self.assertEqual(self._month_day()["leave_count"], 0)
        self.assertEqual(self._day_items(), [])

    def test_refused_leave_still_appears_in_upcoming(self):
        """A future refused leave stays in Upcoming even though it leaves the calendar."""
        refused = self._make_leave("refuse")
        status, body = self._get("/api/mobile/v1/timeoff/upcoming")
        self.assertEqual(status, 200, body)
        # Key is `leaves` (not `upcoming`); an empty `rows` would make the assertion vacuous.
        rows = [row for group in body["data"]["leaves"] for row in group["leaves"]]
        self.assertIn(refused.id, [row["id"] for row in rows])

    def test_refused_leave_still_appears_in_history(self):
        past = date.today() - timedelta(days=30)
        refused = self._make_leave("refuse", day=past)
        status, body = self._get("/api/mobile/v1/timeoff/history")
        self.assertEqual(status, 200, body)
        rows = [row for group in body["data"]["leaves"] for row in group["leaves"]]
        self.assertIn(refused.id, [row["id"] for row in rows])
