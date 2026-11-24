from datetime import date, timedelta

from odoo.tests import HttpCase, tagged


def _next_monday(base=None):
    """First Monday at least a week out — keeps test dates on working days."""
    base = base or date.today()
    target = base + timedelta(days=7)
    return target + timedelta(days=(7 - target.weekday()) % 7)


@tagged("-at_install", "post_install")
class TestMobileTimeoffRequestApi(HttpCase):
    """Tests for the New Leave Request screen: types, duration, create."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        LeaveType = cls.env["hr.leave.type"].sudo()
        Allocation = cls.env["hr.leave.allocation"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        base_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.user = Users.create({
            "name": "Timeoff Mobile User",
            "login": "timeoff_api_user@test.com",
            "password": "timeoff_api_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, base_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Timeoff Mobile User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })

        cls.other_user = Users.create({
            "name": "Other Timeoff User",
            "login": "timeoff_api_other@test.com",
            "password": "timeoff_api_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, base_group.id)],
        })
        cls.other_employee = Employee.create({
            "name": "Other Timeoff User",
            "company_id": company.id,
            "user_id": cls.other_user.id,
        })

        cls.user_no_employee = Users.create({
            "name": "No Employee Timeoff User",
            "login": "timeoff_api_noemp@test.com",
            "password": "timeoff_api_pw_1234",
            "group_ids": [(4, mobile_group.id)],
        })
        cls.user_not_mobile = Users.create({
            "name": "Non Mobile Timeoff User",
            "login": "timeoff_api_nonmobile@test.com",
            "password": "timeoff_api_pw_1234",
            "group_ids": [(4, base_group.id)],
        })

        # Allocated type: 2 days, like the "Sick (2)" chip.
        cls.sick_type = LeaveType.create({
            "name": "API Test Sick",
            "requires_allocation": True,
            "request_unit": "day",
            "leave_validation_type": "hr",
        })
        # Unlimited (no allocation needed) type, like "Unpaid".
        cls.unpaid_type = LeaveType.create({
            "name": "API Test Unpaid",
            "requires_allocation": False,
            "request_unit": "day",
            "leave_validation_type": "hr",
        })
        # Type with no allocation for this employee -- must not be selectable.
        cls.unallocated_type = LeaveType.create({
            "name": "API Test Privilege",
            "requires_allocation": True,
            "request_unit": "day",
            "leave_validation_type": "hr",
        })

        # Feature access is deny-by-default: link the user to Time Off.
        cls._ensure_timeoff_feature_link(cls.env, cls.user)

        allocation = Allocation.create({
            "name": "API Test Sick Allocation",
            "employee_id": cls.employee.id,
            "holiday_status_id": cls.sick_type.id,
            "number_of_days": 2,
            "allocation_type": "regular",
            "date_from": date.today() - timedelta(days=30),
        })
        allocation.action_approve()

        # Working-day anchor: a Monday a week out or more, so Mon+Tue is 2 days and Sun-Tue spans a weekend.
        cls.monday = _next_monday()

    def _token_for(self, login, password):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": login, "password": password},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login unexpectedly failed: %s" % body)
        return body["data"]["token"]

    def _get(self, path, token):
        resp = self.url_open(path, headers={"Authorization": "Bearer %s" % token})
        return resp.status_code, resp.json()

    def _get_without_token(self, path):
        resp = self.url_open(path)
        return resp.status_code, resp.json()

    def _post(self, path, token, payload):
        resp = self.url_open(
            path,
            headers={
                "Authorization": "Bearer %s" % token,
                "Content-Type": "application/json",
            },
            json=payload,
        )
        return resp.status_code, resp.json()

    def _iso(self, d):
        return d.isoformat()

    def test_non_mobile_user_is_rejected_at_login(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": "timeoff_api_nonmobile@test.com",
                  "password": "timeoff_api_pw_1234"},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "mobile_access_denied")

    def _token_then_unlink_employee(self):
        """A token minted while employed, after which HR unlinks the employee.
        Login refuses employee-less users, so this is the only way to reach these guards."""
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        self.employee.write({"user_id": False})
        self.env.flush_all()
        self.addCleanup(self.employee.write, {"user_id": self.user.id})
        return token

    def test_user_without_employee_gets_safe_error(self):
        token = self._token_then_unlink_employee()
        status, body = self._get("/api/mobile/v1/timeoff/types", token)
        self.assertEqual(status, 404)
        self.assertEqual(body["code"], "employee_not_linked")

    def test_calendar_user_without_employee_gets_safe_error(self):
        token = self._token_then_unlink_employee()
        status, body = self._get(
            "/api/mobile/v1/timeoff/calendar/day?date=2026-06-10", token)
        self.assertEqual(status, 404)
        self.assertEqual(body["code"], "employee_not_found")

    def test_types_returns_balance_and_unlimited_flags(self):
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        status, body = self._get("/api/mobile/v1/timeoff/types", token)
        self.assertEqual(status, 200)
        by_id = {t["id"]: t for t in body["data"]}

        sick = by_id.get(self.sick_type.id)
        self.assertIsNotNone(sick, "allocated type missing from types list")
        self.assertEqual(sick["remaining"], 2.0)
        self.assertEqual(sick["remaining_display"], "2")
        self.assertFalse(sick["is_unlimited"])
        self.assertTrue(sick["requires_allocation"])
        self.assertTrue(sick["can_apply"])

        unpaid = by_id.get(self.unpaid_type.id)
        self.assertIsNotNone(unpaid, "no-allocation type missing from types list")
        self.assertIsNone(unpaid["remaining"])
        self.assertEqual(unpaid["remaining_display"], "Unlimited")
        self.assertTrue(unpaid["is_unlimited"])
        self.assertFalse(unpaid["requires_allocation"])

        # No valid allocation -> not selectable, must not appear at all.
        self.assertNotIn(self.unallocated_type.id, by_id)

    def test_duration_counts_working_days_only(self):
        """Sun→Tue spans a weekend: only Mon+Tue count (matches Odoo UI)."""
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        sunday = self.monday - timedelta(days=1)
        tuesday = self.monday + timedelta(days=1)
        status, body = self._post("/api/mobile/v1/timeoff/duration", token, {
            "time_off_type_id": self.unpaid_type.id,
            "start_date": self._iso(sunday),
            "end_date": self._iso(tuesday),
        })
        self.assertEqual(status, 200)
        self.assertEqual(body["data"]["duration"], 2.0)
        self.assertEqual(body["data"]["unit"], "days")
        self.assertTrue(body["data"]["can_apply"])

    def test_duration_rejects_end_before_start(self):
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        status, body = self._post("/api/mobile/v1/timeoff/duration", token, {
            "time_off_type_id": self.unpaid_type.id,
            "start_date": self._iso(self.monday),
            "end_date": self._iso(self.monday - timedelta(days=3)),
        })
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_date_range")

    def test_duration_flags_insufficient_balance(self):
        """5 working days requested vs 2 allocated -> can_apply false."""
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        status, body = self._post("/api/mobile/v1/timeoff/duration", token, {
            "time_off_type_id": self.sick_type.id,
            "start_date": self._iso(self.monday),
            "end_date": self._iso(self.monday + timedelta(days=4)),
        })
        self.assertEqual(status, 200)
        self.assertEqual(body["data"]["duration"], 5.0)
        self.assertFalse(body["data"]["can_apply"])
        self.assertTrue(body["data"]["warning"])

    def test_duration_rejects_unavailable_type(self):
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        status, body = self._post("/api/mobile/v1/timeoff/duration", token, {
            "time_off_type_id": self.unallocated_type.id,
            "start_date": self._iso(self.monday),
            "end_date": self._iso(self.monday),
        })
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_leave_type")

    def _make_calendar_leave(self, employee, start, end, state="confirm",
                             name="Calendar Leave", leave_type=None):
        leave = self.env["hr.leave"].sudo().create({
            "employee_id": employee.id,
            "holiday_status_id": (leave_type or self.unpaid_type).id,
            "request_date_from": start,
            "request_date_to": end,
            "name": name,
        })
        if state != "confirm":
            self.env.cr.execute(
                "UPDATE hr_leave SET state = %s WHERE id = %s",
                [state, leave.id],
            )
            self.env.invalidate_all()
        return leave

    @classmethod
    def _ensure_timeoff_feature_link(cls, env, user):
        """Link *user* to the Time Off feature (grants full access)."""
        feature = env.ref("odx_mobile_connector.feature_leave")
        access = env["mobile.user.feature"].sudo().search([
            ("user_id", "=", user.id),
            ("feature_id", "=", feature.id),
        ], limit=1)
        if not access:
            access = env["mobile.user.feature"].sudo().create({
                "user_id": user.id,
                "feature_id": feature.id,
            })
        return access

    def _revoke_timeoff_feature(self):
        """Unlink the Time Off feature — the only way to deny it now."""
        feature = self.env.ref("odx_mobile_connector.feature_leave")
        self.env["mobile.user.feature"].sudo().search([
            ("user_id", "=", self.user.id),
            ("feature_id", "=", feature.id),
        ]).unlink()

    def _restore_timeoff_feature(self):
        self._ensure_timeoff_feature_link(self.env, self.user)

    def test_calendar_requires_token(self):
        status, body = self._get_without_token(
            "/api/mobile/v1/timeoff/calendar/month?year=2026&month=6")
        self.assertEqual(status, 401)
        self.assertEqual(body["code"], "missing_access_token")

    def test_calendar_invalid_params_are_mobile_safe(self):
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")

        status, body = self._get(
            "/api/mobile/v1/timeoff/calendar/month?year=2026&month=13", token)
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_month")

        status, body = self._get(
            "/api/mobile/v1/timeoff/calendar/month?year=bad&month=6", token)
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_year")

        status, body = self._get(
            "/api/mobile/v1/timeoff/calendar/day?date=not-a-date", token)
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_date")

    def test_calendar_month_counts_multi_day_leave_on_each_date(self):
        self._make_calendar_leave(
            self.employee, date(2026, 6, 10), date(2026, 6, 12),
            state="validate", name="Vacation trip")
        self._make_calendar_leave(
            self.employee, date(2026, 6, 25), date(2026, 6, 25),
            state="confirm", name="Fever")
        self._make_calendar_leave(
            self.other_employee, date(2026, 6, 10), date(2026, 6, 10),
            state="validate", name="Other employee leave")

        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        status, body = self._get(
            "/api/mobile/v1/timeoff/calendar/month?year=2026&month=6", token)
        self.assertEqual(status, 200)
        by_date = {day["date"]: day for day in body["data"]["days"]}

        for value in ("2026-06-10", "2026-06-11", "2026-06-12"):
            self.assertEqual(by_date[value]["leave_count"], 1)
            self.assertEqual(by_date[value]["statuses"], ["approved"])
            self.assertIn("api_test_unpaid", by_date[value]["types"])

        self.assertEqual(by_date["2026-06-25"]["leave_count"], 1)
        self.assertEqual(by_date["2026-06-25"]["statuses"], ["pending"])

    def test_calendar_day_returns_overlap_details_and_not_other_employee(self):
        leave = self._make_calendar_leave(
            self.employee, date(2026, 6, 10), date(2026, 6, 12),
            state="validate1", name="Vacation trip")
        self._make_calendar_leave(
            self.other_employee, date(2026, 6, 11), date(2026, 6, 11),
            state="validate", name="Other employee leave")

        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        status, body = self._get(
            "/api/mobile/v1/timeoff/calendar/day?date=2026-06-11", token)
        self.assertEqual(status, 200)
        items = body["data"]["items"]
        self.assertEqual(len(items), 1)
        item = items[0]
        self.assertEqual(item["id"], leave.id)
        self.assertEqual(item["title"], "Vacation trip")
        self.assertEqual(item["leave_type"], self.unpaid_type.name)
        self.assertEqual(item["leave_type_code"], "api_test_unpaid")
        self.assertEqual(item["start_date"], "2026-06-10")
        self.assertEqual(item["end_date"], "2026-06-12")
        self.assertEqual(item["status"], "pending_second_approval")
        self.assertEqual(item["status_display"], "Second Approval")
        self.assertIn("Days", item["summary_display"])

    def test_calendar_unlinked_feature_denies_access(self):
        self._revoke_timeoff_feature()
        try:
            token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
            status, body = self._get(
                "/api/mobile/v1/timeoff/calendar/month?year=2026&month=6", token)
            self.assertEqual(status, 403)
            self.assertEqual(body["code"], "time_off_access_denied")
        finally:
            self._restore_timeoff_feature()

    def test_upcoming_includes_refused_leave_with_display_label(self):
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        future = self.monday + timedelta(days=60)
        leave = self._make_calendar_leave(
            self.employee, future, future, state="refuse", name="Refused Trip")

        status, body = self._get("/api/mobile/v1/timeoff", token)
        self.assertEqual(status, 200)
        upcoming_ids = {item["id"]: item for item in body["data"]["upcoming"]}
        self.assertIn(leave.id, upcoming_ids,
                      "a refused but still future-dated leave must stay in "
                      "'upcoming', not disappear")
        self.assertEqual(upcoming_ids[leave.id]["stage"], "rejected")
        self.assertEqual(upcoming_ids[leave.id]["stage_display"], "Refused")

    def test_upcoming_excludes_cancelled_leave(self):
        """Cancel is the one state that never belongs in 'upcoming'."""
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        future = self.monday + timedelta(days=61)
        leave = self._make_calendar_leave(
            self.employee, future, future, state="cancel", name="Cancelled Trip")

        status, body = self._get("/api/mobile/v1/timeoff", token)
        self.assertEqual(status, 200)
        upcoming_ids = {item["id"] for item in body["data"]["upcoming"]}
        self.assertNotIn(leave.id, upcoming_ids)

    def test_refused_past_leave_is_history_only(self):
        """Once its own date has passed, refused or not, it leaves 'upcoming'."""
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        past = date.today() - timedelta(days=10)
        leave = self._make_calendar_leave(
            self.employee, past, past, state="refuse", name="Old Refused Trip")

        status, body = self._get("/api/mobile/v1/timeoff", token)
        self.assertEqual(status, 200)
        self.assertNotIn(leave.id, {i["id"] for i in body["data"]["upcoming"]})
        history_ids = {item["id"]: item for item in body["data"]["history"]}
        self.assertIn(leave.id, history_ids)
        self.assertEqual(history_ids[leave.id]["stage_display"], "Refused")

    def test_timeoff_upcoming_endpoint_includes_refused_leave(self):
        """Same guarantee on the dedicated 'See all Upcoming' endpoint."""
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        future = self.monday + timedelta(days=62)
        leave = self._make_calendar_leave(
            self.employee, future, future, state="refuse", name="Refused Trip 2")

        status, body = self._get(
            "/api/mobile/v1/timeoff/upcoming?page=1&page_size=50", token)
        self.assertEqual(status, 200)
        leaves_by_id = {item["id"]: item for group in body["data"]["leaves"]
                        for item in group["leaves"]}
        self.assertIn(leave.id, leaves_by_id)
        self.assertEqual(leaves_by_id[leave.id]["stage_display"], "Refused")

    def test_stage_display_covers_every_stage(self):
        """`stage_display` must read as real words for all four outcomes."""
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        base = date.today() - timedelta(days=20)
        expected = {
            "confirm": "Pending Approval",
            "validate": "Approved",
            "refuse": "Refused",
            "cancel": "Cancelled",
        }
        created = {}
        for offset, (state, _label) in enumerate(expected.items()):
            day = base + timedelta(days=offset)
            created[state] = self._make_calendar_leave(
                self.employee, day, day, state=state,
                name="Stage %s" % state)

        status, body = self._get(
            "/api/mobile/v1/timeoff/history?page=1&page_size=50", token)
        self.assertEqual(status, 200)
        by_id = {item["id"]: item for group in body["data"]["leaves"]
                 for item in group["leaves"]}
        for state, label in expected.items():
            leave_id = created[state].id
            self.assertIn(leave_id, by_id, "state=%s missing from history" % state)
            self.assertEqual(by_id[leave_id]["stage_display"], label,
                             "wrong label for state=%s" % state)

    def test_create_links_to_current_employee_with_reason(self):
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        status, body = self._post("/api/mobile/v1/timeoff/request", token, {
            "time_off_type_id": self.sick_type.id,
            "start_date": self._iso(self.monday),
            "end_date": self._iso(self.monday + timedelta(days=1)),
            "reason": "Family function",
        })
        self.assertEqual(status, 200)
        self.assertEqual(body["data"]["status"], "pending")
        self.assertEqual(body["data"]["duration"], 2.0)
        leave = self.env["hr.leave"].sudo().browse(body["data"]["id"])
        self.assertEqual(leave.employee_id, self.employee)
        self.assertEqual(leave.private_name, "Family function")
        self.assertEqual(leave.state, "confirm")

    def test_create_ignores_client_supplied_employee_id(self):
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        monday2 = self.monday + timedelta(days=14)
        status, body = self._post("/api/mobile/v1/timeoff/request", token, {
            "time_off_type_id": self.unpaid_type.id,
            "start_date": self._iso(monday2),
            "end_date": self._iso(monday2),
            "employee_id": self.other_employee.id,
            "user_id": self.other_user.id,
        })
        self.assertEqual(status, 200)
        leave = self.env["hr.leave"].sudo().browse(body["data"]["id"])
        self.assertEqual(leave.employee_id, self.employee)

    def test_create_optional_reason_missing_is_fine(self):
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        monday3 = self.monday + timedelta(days=21)
        status, body = self._post("/api/mobile/v1/timeoff/request", token, {
            "time_off_type_id": self.unpaid_type.id,
            "start_date": self._iso(monday3),
            "end_date": self._iso(monday3),
        })
        self.assertEqual(status, 200)
        self.assertTrue(body["success"])

    def test_create_rejects_insufficient_balance(self):
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        status, body = self._post("/api/mobile/v1/timeoff/request", token, {
            "time_off_type_id": self.sick_type.id,
            "start_date": self._iso(self.monday + timedelta(days=28)),
            "end_date": self._iso(self.monday + timedelta(days=32)),
        })
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "insufficient_balance")

    def test_create_rejects_end_before_start(self):
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        status, body = self._post("/api/mobile/v1/timeoff/request", token, {
            "time_off_type_id": self.unpaid_type.id,
            "start_date": self._iso(self.monday),
            "end_date": self._iso(self.monday - timedelta(days=2)),
        })
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_date_range")

    def test_rejected_create_leaves_no_orphan_record(self):
        """A create rejected by an Odoo constraint must not persist a row."""
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        monday4 = self.monday + timedelta(days=35)
        payload = {
            "time_off_type_id": self.unpaid_type.id,
            "start_date": self._iso(monday4),
            "end_date": self._iso(monday4),
        }
        status, _ = self._post("/api/mobile/v1/timeoff/request", token, payload)
        self.assertEqual(status, 200)
        count_before = self.env["hr.leave"].sudo().search_count(
            [("employee_id", "=", self.employee.id)])
        # Same dates again -> overlap ValidationError inside create().
        status, body = self._post("/api/mobile/v1/timeoff/request", token, payload)
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "leave_request_invalid")
        count_after = self.env["hr.leave"].sudo().search_count(
            [("employee_id", "=", self.employee.id)])
        self.assertEqual(count_before, count_after,
                         "rejected create must not leave an orphan hr.leave row")

    def test_unexpected_create_failure_is_logged_with_context(self):
        """An unexpected create() failure is logged with a traceback; the client response stays sanitised."""
        original_create = type(self.env["hr.leave"]).create

        def exploding_create(self, vals_list):
            raise KeyError("boom")

        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        payload = {
            "time_off_type_id": self.unpaid_type.id,
            "start_date": self._iso(self.monday + timedelta(days=49)),
            "end_date": self._iso(self.monday + timedelta(days=49)),
        }

        type(self.env["hr.leave"]).create = exploding_create
        try:
            with self.assertLogs(
                "odoo.addons.odx_mobile_api.controllers.timeoff", level="ERROR"
            ) as captured:
                status, body = self._post(
                    "/api/mobile/v1/timeoff/request", token, payload)
        finally:
            type(self.env["hr.leave"]).create = original_create

        # Client contract is unchanged: sanitised message, no internals.
        self.assertEqual(status, 400)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "leave_request_failed")
        self.assertNotIn("KeyError", body["message"])
        self.assertNotIn("Traceback", body["message"])

        # Operators get the real error plus the HR configuration needed to reproduce it.
        logged = "\n".join(captured.output)
        self.assertIn("KeyError", logged)
        self.assertIn("Traceback", logged)
        for marker in ("uid=", "employee=", "manager=", "leave_approver=",
                       "validation=", "dates="):
            self.assertIn(marker, logged,
                          "diagnostic context is missing %r" % marker)

    def test_linked_feature_allows_both_read_and_create(self):
        """A linked feature is full access — there is no read-only level."""
        self._restore_timeoff_feature()
        token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
        status, _ = self._get("/api/mobile/v1/timeoff/types", token)
        self.assertEqual(status, 200)

        status, _ = self._post("/api/mobile/v1/timeoff/request", token, {
            "time_off_type_id": self.unpaid_type.id,
            "start_date": self._iso(self.monday + timedelta(days=42)),
            "end_date": self._iso(self.monday + timedelta(days=42)),
        })
        self.assertNotEqual(status, 403)

    def test_unlinked_feature_denies_create(self):
        self._revoke_timeoff_feature()
        try:
            token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
            status, body = self._post("/api/mobile/v1/timeoff/request", token, {
                "time_off_type_id": self.unpaid_type.id,
                "start_date": self._iso(self.monday + timedelta(days=42)),
                "end_date": self._iso(self.monday + timedelta(days=42)),
            })
            self.assertEqual(status, 403)
            self.assertEqual(body["code"], "time_off_access_denied")
        finally:
            self._restore_timeoff_feature()

    def test_unlinked_feature_denies_types(self):
        self._revoke_timeoff_feature()
        try:
            token = self._token_for("timeoff_api_user@test.com", "timeoff_api_pw_1234")
            status, body = self._get("/api/mobile/v1/timeoff/types", token)
            self.assertEqual(status, 403)
            self.assertEqual(body["code"], "time_off_access_denied")
        finally:
            self._restore_timeoff_feature()
