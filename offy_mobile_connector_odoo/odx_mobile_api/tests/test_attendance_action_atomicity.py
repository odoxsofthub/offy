from datetime import datetime, timedelta
from unittest.mock import patch

import requests

from odoo.exceptions import ConcurrencyError
from odoo.tests import HttpCase, tagged

LOGIN = "att_atomic_user@test.com"
PASSWORD = "att_atomic_pw_1234"


@tagged("post_install", "-at_install")
class TestAttendanceActionAtomicity(HttpCase):
    """A failed check-in/out must not leave a recorded attendance.
    A route that returns an error response still commits, so the row written before the failure must be rolled back.
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        cls.user = cls.env["res.users"].sudo().create({
            "name": "Attendance Atomicity User",
            "login": LOGIN,
            "password": PASSWORD,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = cls.env["hr.employee"].sudo().create({
            "name": "Attendance Atomicity User",
            "company_id": cls.env.ref("base.main_company").id,
            "user_id": cls.user.id,
        })

    # Helpers
    def _token(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": LOGIN, "password": PASSWORD},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"]

    def _action(self, action, token=None, **extra):
        payload = {"action": action}
        payload.update(extra)
        return self.url_open(
            "/api/mobile/v1/attendance/action",
            json=payload,
            headers={"Authorization": "Bearer %s" % (token or self._token()),
                     "Content-Type": "application/json"},
        )

    def _attendances(self):
        return self.env["hr.attendance"].sudo().search(
            [("employee_id", "=", self.employee.id)])

    def _failing_after_write(self, exception):
        """Patch the native action so it really writes, then raises; without the write there is nothing to roll back."""
        Employee = type(self.env["hr.employee"])
        real = Employee._attendance_action_change

        def boom(records, *args, **kwargs):
            real(records, *args, **kwargs)
            raise exception

        return patch.object(Employee, "_attendance_action_change", boom)

    # The reported defect
    def test_a_failed_check_in_records_nothing(self):
        token = self._token()
        with self._failing_after_write(RuntimeError("post-write failure")):
            resp = self._action("check_in", token)

        self.assertEqual(resp.status_code, 500)
        self.assertEqual(resp.json()["code"], "attendance_action_failed")
        self.assertFalse(
            self._attendances(),
            "the API said it failed but recorded the attendance anyway")

    def test_a_failed_check_out_leaves_the_session_open(self):
        """A failed check-out must leave the session open."""
        token = self._token()
        resp = self._action("check_in", token)
        self.assertEqual(resp.status_code, 200, resp.text)

        with self._failing_after_write(RuntimeError("post-write failure")):
            resp = self._action("check_out", token)
        self.assertEqual(resp.status_code, 500)

        attendance = self._attendances()
        self.assertEqual(len(attendance), 1)
        self.assertFalse(attendance.check_out,
                         "the check-out was applied despite reporting failure")

    def test_the_retry_after_a_failure_succeeds(self):
        """The retry after a failure must succeed."""
        token = self._token()
        self._action("check_in", token)
        with self._failing_after_write(RuntimeError("post-write failure")):
            self.assertEqual(self._action("check_out", token).status_code, 500)

        resp = self._action("check_out", token)
        self.assertEqual(resp.status_code, 200, resp.text)
        self.assertTrue(resp.json()["success"])
        self.assertTrue(self._attendances().check_out)

    def test_the_refresh_agrees_with_the_error(self):
        """The third symptom: refreshing must NOT reveal a different story."""
        token = self._token()
        with self._failing_after_write(RuntimeError("post-write failure")):
            self._action("check_in", token)

        resp = self.url_open(
            "/api/mobile/v1/home",
            headers={"Authorization": "Bearer %s" % token})
        card = resp.json()["data"]["home"]["attendance"]
        self.assertEqual(card["status"], "not_checked_in")
        self.assertIsNone(card["check_in"])

    # Retryable database errors
    def test_a_concurrency_error_is_not_swallowed(self):
        """Concurrency errors must propagate so Odoo's own request retry can absorb them, not become a 500."""
        token = self._token()
        with self._failing_after_write(ConcurrencyError("serialization")):
            try:
                body = self._action("check_in", token).text
            except requests.exceptions.RequestException:
                # Retries exhausted and the error propagated: our code did not turn it into its own answer.
                body = ""

        self.assertNotIn(
            "attendance_action_failed", body,
            "a retryable database error was converted into a flat failure")
        self.assertFalse(self._attendances(),
                         "nothing may survive a retried-and-abandoned request")

    # Must not regress the normal path
    def test_a_normal_check_in_and_out_still_records(self):
        token = self._token()
        resp = self._action("check_in", token, latitude=9.9312, longitude=76.2673)
        self.assertEqual(resp.status_code, 200, resp.text)
        resp = self._action("check_out", token, latitude=9.9312, longitude=76.2673)
        self.assertEqual(resp.status_code, 200, resp.text)

        attendance = self._attendances()
        self.assertEqual(len(attendance), 1)
        self.assertTrue(attendance.check_in and attendance.check_out)
        # Location markers are written inside the savepoint; they must still commit on the happy path.
        self.assertTrue(attendance.mobile_check_in_location_enabled)
        self.assertTrue(attendance.mobile_check_out_location_enabled)

    def test_double_check_in_never_creates_a_second_row(self):
        token = self._token()
        self.assertEqual(self._action("check_in", token).status_code, 200)
        resp = self._action("check_in", token)
        # A replay, not a conflict; see the replay tests below.
        self.assertEqual(resp.status_code, 200, resp.text)
        self.assertTrue(resp.json()["data"]["already_recorded"])
        self.assertEqual(len(self._attendances()), 1)


    # Replay: the write committed but the response was lost
    def _record(self, minutes_ago_in, minutes_ago_out=None):
        """An attendance written directly, `minutes_ago_*` in the past."""
        now = datetime.utcnow()
        vals = {"employee_id": self.employee.id,
                "check_in": now - timedelta(minutes=minutes_ago_in)}
        if minutes_ago_out is not None:
            vals["check_out"] = now - timedelta(minutes=minutes_ago_out)
        return self.env["hr.attendance"].sudo().create(vals)

    def test_a_retried_check_out_after_a_lost_response_is_replayed(self):
        """A check-out retried after a lost response is replayed as 200 with `already_recorded`, not a 409."""
        token = self._token()
        self.assertEqual(self._action("check_in", token).status_code, 200)
        committed = self._action("check_out", token)   # response "lost"
        self.assertEqual(committed.status_code, 200, committed.text)

        resp = self._action("check_out", token)
        self.assertEqual(resp.status_code, 200, resp.text)
        body = resp.json()
        self.assertTrue(body["success"])
        self.assertTrue(body["data"]["already_recorded"])
        self.assertEqual(body["data"]["attendance"]["status"], "checked_out")
        self.assertEqual(body["data"]["attendance"]["id"],
                         committed.json()["data"]["attendance"]["id"])
        self.assertEqual(len(self._attendances()), 1, "the replay recorded something")

    def test_the_replay_has_the_shape_the_app_parses(self):
        """The app reads `data.attendance` on success and nothing else, so a
        replay must be structurally indistinguishable from a fresh result."""
        token = self._token()
        self._action("check_in", token)
        fresh = self._action("check_out", token).json()["data"]["attendance"]
        replay = self._action("check_out", token).json()["data"]["attendance"]
        self.assertEqual(set(replay), set(fresh))
        self.assertEqual(replay, fresh)

    def test_a_replay_needs_no_gps(self):
        """A replay records nothing, so where the phone is NOW is irrelevant
        -- the original action passed the fence when it was written."""
        config = self.env["mobile.config"].sudo().search([], limit=1)
        config.write({
            "attendance_gps_required": True,
            "attendance_checkout_gps_required": True,
            "company_latitude": 9.9312, "company_longitude": 76.2673,
        })
        self._record(minutes_ago_in=60, minutes_ago_out=1)
        resp = self._action("check_out", latitude=51.5074, longitude=-0.1278)  # London
        self.assertEqual(resp.status_code, 200, resp.text)
        self.assertTrue(resp.json()["data"]["already_recorded"])

    def test_a_stale_check_out_outside_the_window_is_still_refused(self):
        """Outside the replay window a stale state mismatch still gets the informative conflict."""
        self._record(minutes_ago_in=120, minutes_ago_out=10)
        resp = self._action("check_out")
        self.assertEqual(resp.status_code, 409, resp.text)
        self.assertEqual(resp.json()["code"], "not_checked_in")

    def test_a_stale_check_in_outside_the_window_is_still_refused(self):
        self._record(minutes_ago_in=10)
        resp = self._action("check_in")
        self.assertEqual(resp.status_code, 409, resp.text)
        self.assertEqual(resp.json()["code"], "already_checked_in")

    def test_stepping_out_and_back_in_is_never_mistaken_for_a_replay(self):
        """Checked out a minute ago, now checking IN: that is new work. A
        check-in replay requires an OPEN session, so this must record."""
        token = self._token()
        self._action("check_in", token)
        self._action("check_out", token)
        resp = self._action("check_in", token)
        self.assertEqual(resp.status_code, 200, resp.text)
        self.assertNotIn("already_recorded", resp.json()["data"])
        self.assertEqual(len(self._attendances()), 2)

    def test_a_check_out_while_checked_in_is_real_work(self):
        token = self._token()
        self._action("check_in", token)
        resp = self._action("check_out", token)
        self.assertEqual(resp.status_code, 200, resp.text)
        self.assertNotIn("already_recorded", resp.json()["data"])
        self.assertTrue(self._attendances().check_out)
