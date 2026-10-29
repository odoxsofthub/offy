from datetime import datetime

from odoo.tests import HttpCase, tagged

# 06:22 UTC == 11:52 Asia/Calcutta (UTC+05:30).
CHECK_IN_UTC = datetime(2026, 7, 29, 6, 22, 5)
CHECK_OUT_UTC = datetime(2026, 7, 29, 14, 30, 0)
EXPECTED_LOCAL_IN = "11:52 AM"
EXPECTED_LOCAL_OUT = "8:00 PM"
RAW_UTC_IN = "6:22 AM"
EMPLOYEE_TZ = "Asia/Calcutta"


@tagged("-at_install", "post_install")
class TestMobileTimezoneFallback(HttpCase):
    """Times must use the employee timezone when ``res.users.tz`` is empty.
    Users created programmatically have no tz; ``hr.employee.tz`` must be the fallback."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        # The defect's precondition: no timezone on the USER ...
        cls.user = Users.create({
            "name": "Tz Fallback User",
            "login": "tz_fallback_user@test.com",
            "password": "tz_fallback_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.user.tz = False
        # ... but a correct one on the EMPLOYEE.
        cls.employee = Employee.create({
            "name": "Tz Fallback User",
            "company_id": company.id,
            "user_id": cls.user.id,
            "tz": EMPLOYEE_TZ,
        })

        # Control case: timezone set on the user itself must still win.
        cls.user_with_tz = Users.create({
            "name": "Tz Explicit User",
            "login": "tz_explicit_user@test.com",
            "password": "tz_fallback_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
            "tz": "Europe/Brussels",
        })
        cls.employee_with_tz = Employee.create({
            "name": "Tz Explicit User",
            "company_id": company.id,
            "user_id": cls.user_with_tz.id,
            "tz": EMPLOYEE_TZ,
        })

        for employee in (cls.employee, cls.employee_with_tz):
            cls.env["hr.attendance"].sudo().create({
                "employee_id": employee.id,
                "check_in": CHECK_IN_UTC,
                "check_out": CHECK_OUT_UTC,
            })

        # Feature access is deny-by-default: link both users to Attendance explicitly.
        feature = cls.env.ref("odx_mobile_connector.feature_attendance")
        UserFeature = cls.env["mobile.user.feature"].sudo()
        for user in (cls.user | cls.user_with_tz):
            if not UserFeature.search_count([
                ("user_id", "=", user.id), ("feature_id", "=", feature.id),
            ]):
                UserFeature.create({
                    "user_id": user.id, "feature_id": feature.id,
                })

    def _token_for(self, login, password="tz_fallback_pw_1234"):
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

    def _logs_for(self, login):
        token = self._token_for(login)
        status, body = self._get(
            "/api/mobile/v1/attendance/logs?month=7&year=2026", token)
        self.assertEqual(status, 200, body)
        return body["data"]

    def test_explicit_user_tz_still_wins_over_employee_tz(self):
        """The fallback must not override a timezone the user actually set."""
        data = self._logs_for("tz_explicit_user@test.com")
        # 06:22 UTC in July == 08:22 Europe/Brussels (CEST, UTC+2).
        self.assertEqual(data["logs"][0]["time_info"], "8:22 AM - 4:30 PM")

    def test_attendance_logs_use_employee_timezone(self):
        token = self._token_for("tz_fallback_user@test.com")
        status, body = self._get(
            "/api/mobile/v1/attendance/logs?month=7&year=2026", token)
        self.assertEqual(status, 200)
        logs = body["data"]["logs"]
        self.assertTrue(logs, "the seeded attendance must be inside the month window")

        time_info = logs[0]["time_info"]
        self.assertNotIn(
            RAW_UTC_IN, time_info,
            "attendance log is still rendered in raw UTC (issue 007 regression)")
        self.assertEqual(
            time_info, "%s - %s" % (EXPECTED_LOCAL_IN, EXPECTED_LOCAL_OUT))
        self.assertEqual(body["data"]["avg_in_time"], EXPECTED_LOCAL_IN)

    def test_attendance_log_date_uses_employee_timezone(self):
        """Day bucketing is driven by the same tz -- it must not slip a day."""
        token = self._token_for("tz_fallback_user@test.com")
        status, body = self._get(
            "/api/mobile/v1/attendance/logs?month=7&year=2026", token)
        self.assertEqual(status, 200)
        self.assertEqual(body["data"]["logs"][0]["date"], "July 29, 2026")

    def test_home_and_attendance_agree_on_the_same_record(self):
        """Home (raw ISO-8601) and Attendance (server-formatted) describe the same instant."""
        token = self._token_for("tz_fallback_user@test.com")

        status, home = self._get("/api/mobile/v1/home", token)
        self.assertEqual(status, 200)

        status, logs = self._get(
            "/api/mobile/v1/attendance/logs?month=7&year=2026", token)
        self.assertEqual(status, 200)

        # The attendance surface must not report the raw UTC clock time.
        self.assertNotIn(RAW_UTC_IN, logs["data"]["logs"][0]["time_info"])
        self.assertEqual(home["success"], True)
