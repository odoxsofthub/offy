from odoo.tests import HttpCase, tagged

# Malformed inputs a client can send: wrong format, locale format, impossible date, free text.
BAD_DATES = ("not-a-date", "01/02/2026", "2026-13-45", "yesterday", "2026-02-30")


@tagged("-at_install", "post_install")
class TestMobileMalformedDates(HttpCase):
    """Malformed request dates must return a JSON error, not an HTTP 500.
    ``fields.Date.to_date`` raises on bad input, so parsing goes through ``main.parse_date``."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.user = Users.create({
            "name": "Bad Date User",
            "login": "bad_date_user@test.com",
            "password": "bad_date_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Bad Date User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })
        cls.leave_type = cls.env["hr.leave.type"].sudo().create({
            "name": "Bad Date Leave",
            "requires_allocation": False,
            "request_unit": "day",
            "leave_validation_type": "hr",
        })

    def _token(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": "bad_date_user@test.com", "password": "bad_date_pw_1234"},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login unexpectedly failed: %s" % body)
        return body["data"]["token"]

    def _assert_json_envelope(self, resp, expected_code, context):
        """A malformed date must yield the JSON envelope, never an HTML 500."""
        self.assertEqual(
            resp.status_code, 400,
            "%s returned HTTP %s, not 400 -- an unhandled exception escaped "
            "(issue 016 regression). Body: %.200s"
            % (context, resp.status_code, resp.text))
        self.assertTrue(
            resp.headers.get("Content-Type", "").startswith("application/json"),
            "%s did not return JSON. Body: %.200s" % (context, resp.text))
        body = resp.json()
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], expected_code, context)

    def _post(self, path, token, payload):
        return self.url_open(
            path,
            headers={"Authorization": "Bearer %s" % token,
                     "Content-Type": "application/json"},
            json=payload,
        )

    def _get(self, path, token):
        return self.url_open(path, headers={"Authorization": "Bearer %s" % token})

    def test_timeoff_request_rejects_malformed_start_date(self):
        token = self._token()
        for bad in BAD_DATES:
            resp = self._post("/api/mobile/v1/timeoff/request", token, {
                "time_off_type_id": self.leave_type.id,
                "start_date": bad,
                "end_date": "2026-08-06",
            })
            self._assert_json_envelope(
                resp, "invalid_date", "timeoff/request start_date=%r" % bad)

    def test_timeoff_request_rejects_malformed_end_date(self):
        token = self._token()
        resp = self._post("/api/mobile/v1/timeoff/request", token, {
            "time_off_type_id": self.leave_type.id,
            "start_date": "2026-08-05",
            "end_date": "2026-13-45",
        })
        self._assert_json_envelope(resp, "invalid_date", "timeoff/request end_date")

    def test_timeoff_duration_rejects_malformed_date(self):
        token = self._token()
        for bad in BAD_DATES:
            resp = self._post("/api/mobile/v1/timeoff/duration", token, {
                "time_off_type_id": self.leave_type.id,
                "start_date": bad,
                "end_date": "2026-08-06",
            })
            self._assert_json_envelope(
                resp, "invalid_date", "timeoff/duration start_date=%r" % bad)

    def test_expense_list_rejects_malformed_date_from(self):
        token = self._token()
        for bad in BAD_DATES:
            resp = self._get(
                "/api/mobile/v1/expense?date_from=%s" % bad, token)
            self._assert_json_envelope(
                resp, "invalid_date", "expense date_from=%r" % bad)

    def test_expense_list_rejects_malformed_date_to(self):
        token = self._token()
        resp = self._get("/api/mobile/v1/expense?date_to=2026-13-45", token)
        self._assert_json_envelope(resp, "invalid_date", "expense date_to")

    def test_recent_activities_rejects_malformed_dates(self):
        token = self._token()
        for param in ("date_from", "date_to"):
            resp = self._get(
                "/api/mobile/v1/recent-activities?%s=not-a-date" % param, token)
            self._assert_json_envelope(
                resp, "invalid_date_range", "recent-activities %s" % param)

    def test_valid_dates_are_still_accepted(self):
        token = self._token()
        resp = self._post("/api/mobile/v1/timeoff/duration", token, {
            "time_off_type_id": self.leave_type.id,
            "start_date": "2026-08-05",
            "end_date": "2026-08-06",
        })
        self.assertEqual(resp.status_code, 200, resp.text)
        self.assertTrue(resp.json()["success"])

    def test_empty_date_still_reports_missing_not_malformed(self):
        """Missing and malformed both yield None; the message must fit."""
        token = self._token()
        resp = self._post("/api/mobile/v1/timeoff/duration", token, {
            "time_off_type_id": self.leave_type.id,
            "start_date": "",
            "end_date": "2026-08-06",
        })
        self._assert_json_envelope(resp, "invalid_date", "timeoff/duration empty")
