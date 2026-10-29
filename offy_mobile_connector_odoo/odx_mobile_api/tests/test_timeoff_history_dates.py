from datetime import date, timedelta

from odoo.tests import HttpCase, tagged

PASSWORD = "timeoff_history_pw_1234"
LOGIN = "timeoff_history_user@test.com"


@tagged("-at_install", "post_install")
class TestMobileTimeoffHistoryDates(HttpCase):
    """`/timeoff/history` and `/timeoff`'s history section list past dates only, whatever the state.
    A future refused leave stays in Upcoming; a future cancelled one is in neither list."""

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
            "name": "Timeoff History User",
            "login": LOGIN,
            "password": PASSWORD,
            "group_ids": [(4, mobile_group.id), (4, base_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Timeoff History User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })
        cls.leave_type = LeaveType.create({
            "name": "History Test Leave",
            "requires_allocation": False,
            "request_unit": "day",
            "leave_validation_type": "hr",
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

    def _make_leave(self, state, day):
        """A leave forced into `state` via SQL, bypassing the approval workflow."""
        leave = self.env["hr.leave"].sudo().create({
            "employee_id": self.employee.id,
            "holiday_status_id": self.leave_type.id,
            "request_date_from": day,
            "request_date_to": day,
        })
        self.env.cr.execute(
            "UPDATE hr_leave SET state = %s WHERE id = %s", [state, leave.id])
        self.env.invalidate_all()
        return leave

    def _history_ids(self, token):
        resp = self.url_open(
            "/api/mobile/v1/timeoff/history?page=1&page_size=50",
            headers={"Authorization": "Bearer %s" % token})
        body = resp.json()
        self.assertTrue(body["success"], body)
        return {l["id"] for group in body["data"]["leaves"]
                for l in group["leaves"]}

    def _upcoming_ids(self, token):
        resp = self.url_open(
            "/api/mobile/v1/timeoff/upcoming?page=1&page_size=50",
            headers={"Authorization": "Bearer %s" % token})
        body = resp.json()
        self.assertTrue(body["success"], body)
        return {l["id"] for group in body["data"]["leaves"]
                for l in group["leaves"]}

    def _dashboard(self, token):
        resp = self.url_open(
            "/api/mobile/v1/timeoff?history_limit=50&upcoming_limit=3",
            headers={"Authorization": "Bearer %s" % token})
        body = resp.json()
        self.assertTrue(body["success"], body)
        return body["data"]

    def test_future_refused_leave_is_not_in_history(self):
        """The regression itself."""
        future = date.today() + timedelta(days=30)
        leave = self._make_leave("refuse", future)
        token = self._token()
        self.assertNotIn(
            leave.id, self._history_ids(token),
            "a refused leave for a future date must not appear in history yet")

    def test_future_cancelled_leave_is_not_in_history(self):
        future = date.today() + timedelta(days=30)
        leave = self._make_leave("cancel", future)
        token = self._token()
        self.assertNotIn(leave.id, self._history_ids(token))

    def test_past_refused_leave_is_in_history(self):
        """The other half: a past-dated refusal must still show -- this was
        never in question, but the fix must not overcorrect into hiding it."""
        past = date.today() - timedelta(days=10)
        leave = self._make_leave("refuse", past)
        token = self._token()
        self.assertIn(leave.id, self._history_ids(token))

    def test_past_cancelled_leave_is_in_history(self):
        past = date.today() - timedelta(days=10)
        leave = self._make_leave("cancel", past)
        token = self._token()
        self.assertIn(leave.id, self._history_ids(token))

    def test_past_approved_leave_is_in_history(self):
        """History is "any status, past date" -- not specific to refuse/cancel."""
        past = date.today() - timedelta(days=10)
        leave = self._make_leave("validate", past)
        token = self._token()
        self.assertIn(leave.id, self._history_ids(token))

    def test_future_approved_leave_is_not_in_history(self):
        future = date.today() + timedelta(days=30)
        leave = self._make_leave("validate", future)
        token = self._token()
        self.assertNotIn(leave.id, self._history_ids(token))

    def test_future_refused_leave_appears_in_upcoming_instead(self):
        future = date.today() + timedelta(days=30)
        leave = self._make_leave("refuse", future)
        token = self._token()
        self.assertIn(
            leave.id, self._upcoming_ids(token),
            "dropping it from history must not make it disappear entirely")

    def test_future_cancelled_leave_appears_in_neither_list(self):
        """A future cancelled leave is never upcoming, so it appears in neither list."""
        future = date.today() + timedelta(days=30)
        leave = self._make_leave("cancel", future)
        token = self._token()
        self.assertNotIn(leave.id, self._upcoming_ids(token))
        self.assertNotIn(leave.id, self._history_ids(token))

    def test_dashboard_history_section_excludes_future_refused_leave(self):
        future = date.today() + timedelta(days=30)
        leave = self._make_leave("refuse", future)
        token = self._token()
        data = self._dashboard(token)
        history_ids = {l["id"] for l in data["history"]}
        self.assertNotIn(leave.id, history_ids)

    def test_dashboard_history_section_includes_past_leave(self):
        past = date.today() - timedelta(days=10)
        leave = self._make_leave("refuse", past)
        token = self._token()
        data = self._dashboard(token)
        history_ids = {l["id"] for l in data["history"]}
        self.assertIn(leave.id, history_ids)
