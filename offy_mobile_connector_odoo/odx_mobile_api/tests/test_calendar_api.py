from datetime import datetime, timedelta

from odoo.tests import HttpCase, tagged


@tagged("-at_install", "post_install")
class TestMobileCalendarApi(HttpCase):
    """Tests for mobile calendar month/day APIs."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.user = Users.create({
            "name": "Calendar Api User",
            "login": "calendar_api_user@test.com",
            "password": "calendar_api_pw_1234",
            "tz": "Asia/Kolkata",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Calendar Api User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })

        cls.other_user = Users.create({
            "name": "Calendar Api Other User",
            "login": "calendar_api_other@test.com",
            "password": "calendar_api_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })

        cls.leave_type = cls.env["hr.leave.type"].sudo().create({
            "name": "Calendar Api Leave",
            "requires_allocation": False,
            "company_id": company.id,
        })

        cls.event = cls.env["calendar.event"].sudo().create({
            "name": "Daily Stand-up Meeting",
            "start": datetime(2026, 6, 9, 2, 30),
            "stop": datetime(2026, 6, 9, 3, 0),
            "user_id": cls.user.id,
            "partner_ids": [(4, cls.user.partner_id.id)],
            "notes": "<p>Discuss sprint blockers</p>",
            "description": "<div><strong>Organized by</strong><br>Calendar Api User</div>",
        })
        cls.all_day_event = cls.env["calendar.event"].sudo().create({
            "name": "Company Workshop",
            "allday": True,
            "start_date": datetime(2026, 6, 9).date(),
            "stop_date": datetime(2026, 6, 9).date(),
            "user_id": cls.user.id,
            "partner_ids": [(4, cls.user.partner_id.id)],
            "notes": "<p>Bring laptop</p>",
        })
        cls.no_note_event = cls.env["calendar.event"].sudo().create({
            "name": "Backend Created Event",
            "allday": True,
            "start_date": datetime(2026, 6, 9).date(),
            "stop_date": datetime(2026, 6, 9).date(),
            "user_id": cls.user.id,
            "partner_ids": [(4, cls.user.partner_id.id)],
        })
        cls.other_event = cls.env["calendar.event"].sudo().create({
            "name": "Other User Private Meeting",
            "start": datetime(2026, 6, 9, 4, 30),
            "stop": datetime(2026, 6, 9, 5, 0),
            "user_id": cls.other_user.id,
            "partner_ids": [(4, cls.other_user.partner_id.id)],
        })
        cls.shared_other_event = cls.env["calendar.event"].sudo().create({
            "name": "Other User Shared Meeting",
            "start": datetime(2026, 6, 9, 6, 0),
            "stop": datetime(2026, 6, 9, 6, 30),
            "user_id": cls.other_user.id,
            "partner_ids": [(4, cls.user.partner_id.id)],
        })
        cls.leave = cls.env["hr.leave"].sudo().create({
            "employee_id": cls.employee.id,
            "holiday_status_id": cls.leave_type.id,
            "request_date_from": datetime(2026, 6, 10).date(),
            "request_date_to": datetime(2026, 6, 10).date(),
        })
        # Approval makes Odoo create the mirror calendar.event, the duplicate these tests guard against.
        cls.leave.sudo().action_approve()

        # Left pending on purpose -- must NOT appear on the calendar.
        cls.pending_leave = cls.env["hr.leave"].sudo().create({
            "employee_id": cls.employee.id,
            "holiday_status_id": cls.leave_type.id,
            "request_date_from": datetime(2026, 6, 11).date(),
            "request_date_to": datetime(2026, 6, 11).date(),
        })
        cls.env.flush_all()

    def _token_for(self, login, password):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": login, "password": password},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login unexpectedly failed: %s" % body)
        return body["data"]["token"]

    def _get(self, path, token=None, **params):
        headers = {"Authorization": "Bearer %s" % token} if token else {}
        resp = self.url_open(path, headers=headers, params=params or None)
        return resp.status_code, resp.json()

    def _post(self, path, payload, token):
        resp = self.url_open(
            path, json=payload,
            headers={"Authorization": "Bearer %s" % token,
                     "Content-Type": "application/json"},
        )
        return resp.status_code, resp.json()

    def _delete(self, path, token):
        resp = self.url_open(
            path, method="DELETE",
            headers={"Authorization": "Bearer %s" % token},
        )
        return resp.status_code, resp.json()

    def test_missing_token_gets_json_error(self):
        status, body = self._get("/api/mobile/v1/calendar/month", year=2026, month=6)
        self.assertEqual(status, 401)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "missing_access_token")
        self.assertIn("message", body)

    def test_month_counts_user_calendar_items(self):
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._get(
            "/api/mobile/v1/calendar/month", token, year=2026, month=6)
        self.assertEqual(status, 200)
        day9 = next(d for d in body["data"]["days"] if d["date"] == "2026-06-09")
        day10 = next(d for d in body["data"]["days"] if d["date"] == "2026-06-10")
        # Own stand-up, workshop and backend event, plus the shared meeting the user attends.
        self.assertEqual(day9["item_count"], 4)
        self.assertEqual(day9["types"], ["meeting"])
        _status, day_body = self._get("/api/mobile/v1/calendar/day", token, date="2026-06-09")
        self.assertEqual(day9["item_count"], len(day_body["data"]["items"]))
        # 1, not 2: the approved leave's mirror calendar.event is not counted, only the leave.
        self.assertEqual(day10["item_count"], 1)
        self.assertEqual(day10["types"], ["time_off"])

    def test_approved_leave_appears_once_not_twice(self):
        """An approved leave appears once, not again via its mirrored `calendar.event`."""
        self.assertTrue(
            self.leave.meeting_id,
            "fixture precondition: approving the leave should mirror it")

        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._get(
            "/api/mobile/v1/calendar/day", token, date="2026-06-10")
        self.assertEqual(status, 200)
        items = body["data"]["items"]
        self.assertEqual(len(items), 1, items)
        self.assertEqual(items[0]["source_model"], "hr.leave")
        self.assertEqual(items[0]["type"], "time_off")
        self.assertNotIn(
            "calendar.event:%s" % self.leave.meeting_id.id,
            [item["id"] for item in items])

    def test_leave_title_matches_the_excluded_mirrors_wording(self):
        """The leave title reuses Odoo's mirror wording; type and reason move to `subtitle`."""
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._get(
            "/api/mobile/v1/calendar/day", token, date="2026-06-10")
        self.assertEqual(status, 200)
        item = body["data"]["items"][0]
        self.assertEqual(
            item["title"],
            "%s on Time Off : %s" % (
                self.employee.name, self.leave.duration_display))
        self.assertIn(self.leave_type.name, item["subtitle"])

    def test_pending_leave_is_not_on_the_calendar(self):
        """A leave still awaiting approval is not shown on this calendar."""
        self.assertEqual(self.pending_leave.state, "confirm")
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._get(
            "/api/mobile/v1/calendar/day", token, date="2026-06-11")
        self.assertEqual(status, 200)
        self.assertEqual(body["data"]["items"], [])

    def test_ordinary_meetings_are_still_served(self):
        """The mirror filter keys on `res_model`, which a normal event leaves
        NULL -- so it must not sweep genuine meetings away with it."""
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._get(
            "/api/mobile/v1/calendar/day", token, date="2026-06-09")
        self.assertEqual(status, 200)
        models = {item["source_model"] for item in body["data"]["items"]}
        self.assertEqual(models, {"calendar.event"})
        self.assertTrue(body["data"]["items"])

    def test_day_returns_details_without_other_users_items(self):
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._get(
            "/api/mobile/v1/calendar/day", token, date="2026-06-09")
        self.assertEqual(status, 200)
        titles = [item["title"] for item in body["data"]["items"]]
        self.assertIn("Daily Stand-up Meeting", titles)
        self.assertNotIn("Other User Private Meeting", titles)
        item = body["data"]["items"][0]
        self.assertEqual(item["source_model"], "calendar.event")
        self.assertEqual(item["type"], "meeting")
        self.assertEqual(item["subtitle"], "Discuss sprint blockers")
        self.assertEqual(item["start"], "2026-06-09T08:00:00")
        self.assertTrue(item["is_deletable"])

    def test_calendar_items_expose_delete_permission(self):
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._get(
            "/api/mobile/v1/calendar/day", token, date="2026-06-09")
        self.assertEqual(status, 200)
        by_title = {item["title"]: item for item in body["data"]["items"]}
        self.assertTrue(by_title["Daily Stand-up Meeting"]["is_deletable"])
        self.assertFalse(by_title["Other User Shared Meeting"]["is_deletable"])

    def test_owner_can_delete_created_event(self):
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._delete(
            "/api/mobile/v1/calendar/events/%s" % self.event.id, token)
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"])
        self.assertFalse(self.event.exists())

    def test_attendee_cannot_delete_another_users_event(self):
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._delete(
            "/api/mobile/v1/calendar/events/%s" % self.shared_other_event.id,
            token)
        self.assertEqual(status, 403, body)
        self.assertEqual(body["code"], "calendar_event_delete_denied")
        self.assertTrue(self.shared_other_event.exists())

    def test_day_calendar_items_include_all_day_and_dates(self):
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._get(
            "/api/mobile/v1/calendar/day", token, date="2026-06-09")
        self.assertEqual(status, 200)
        item = next(
            item for item in body["data"]["items"]
            if item["title"] == "Company Workshop"
        )
        self.assertTrue(item["all_day"])
        self.assertEqual(item["time_display"], "All day")
        self.assertEqual(item["start"], "2026-06-09")
        self.assertEqual(item["end"], "2026-06-09")
        self.assertEqual(item["subtitle"], "Bring laptop")

    def test_day_calendar_event_without_note_returns_empty_subtitle(self):
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._get(
            "/api/mobile/v1/calendar/day", token, date="2026-06-09")
        self.assertEqual(status, 200)
        item = next(
            item for item in body["data"]["items"]
            if item["title"] == "Backend Created Event"
        )
        self.assertIsNone(item["subtitle"])

    def test_invalid_day_date_is_mobile_safe(self):
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._get(
            "/api/mobile/v1/calendar/day", token, date="bad-date")
        self.assertEqual(status, 400)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "invalid_date")

    def test_unlinked_feature_denies_calendar(self):
        """Access is deny-by-default: no link row means no calendar."""
        feature = self.env.ref("odx_mobile_connector.feature_calendar")
        self.env["mobile.user.feature"].sudo().search([
            ("user_id", "=", self.user.id),
            ("feature_id", "=", feature.id),
        ]).unlink()
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._get(
            "/api/mobile/v1/calendar/month", token, year=2026, month=6)
        self.assertEqual(status, 403)
        self.assertEqual(body["code"], "calendar_access_denied")

    def test_create_timed_event_uses_users_timezone(self):
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._post("/api/mobile/v1/calendar/events", {
            "title": "Mobile Planning", "all_day": False,
            "start_date": "2026-06-12", "start_time": "02:30 PM",
            "end_date": "2026-06-12", "end_time": "15:30",
            "notes": "Plan the release",
        }, token)
        self.assertEqual(status, 201, body)
        event = body["data"]["event"]
        self.assertEqual(event["title"], "Mobile Planning")
        self.assertFalse(event["all_day"])
        self.assertEqual(event["start"], "2026-06-12T14:30:00")
        self.assertEqual(event["end"], "2026-06-12T15:30:00")
        self.assertEqual(event["subtitle"], "Plan the release")

    def test_create_all_day_event_ignores_times(self):
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._post("/api/mobile/v1/calendar/events", {
            "title": "Mobile Workshop", "all_day": True,
            "start_date": "2026-06-12", "start_time": "02:30 PM",
            "end_date": "2026-06-13", "end_time": "01:00 AM",
        }, token)
        self.assertEqual(status, 201, body)
        event = body["data"]["event"]
        self.assertTrue(event["all_day"])
        self.assertEqual(event["start"], "2026-06-12")
        self.assertEqual(event["end"], "2026-06-13")

    def test_create_timed_event_requires_end_after_start(self):
        token = self._token_for("calendar_api_user@test.com", "calendar_api_pw_1234")
        status, body = self._post("/api/mobile/v1/calendar/events", {
            "title": "Invalid Meeting", "all_day": False,
            "start_date": "2026-06-12", "start_time": "15:30",
            "end_date": "2026-06-12", "end_time": "14:30",
        }, token)
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "invalid_time_range")
