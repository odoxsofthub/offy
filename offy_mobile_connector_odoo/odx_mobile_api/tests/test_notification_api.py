import json

from odoo.tests import HttpCase, tagged


@tagged("-at_install", "post_install")
class TestMobileNotificationApi(HttpCase):
    """Tests for GET /api/mobile/v1/notifications."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.user = Users.create({
            "name": "Notification Api User",
            "login": "notification_api_user@test.com",
            "password": "notification_api_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.other_user = Users.create({
            "name": "Notification Api Other User",
            "login": "notification_api_other@test.com",
            "password": "notification_api_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        # Login refuses employee-less accounts (see test_auth_employment_gate.py).
        cls.employee = Employee.create({
            "name": "Notification Api User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })
        cls.other_employee = Employee.create({
            "name": "Notification Api Other User",
            "company_id": company.id,
            "user_id": cls.other_user.id,
        })

    def _token(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": "notification_api_user@test.com",
                  "password": "notification_api_pw_1234"},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login unexpectedly failed: %s" % body)
        return body["data"]["token"]

    def _get(self, token=None, **params):
        headers = {"Authorization": "Bearer %s" % token} if token else {}
        resp = self.url_open(
            "/api/mobile/v1/notifications",
            headers=headers,
            params=params or None,
        )
        return resp.status_code, resp.json()

    def _delete(self, notification_id, token):
        resp = self.url_open(
            "/api/mobile/v1/notifications/%s" % notification_id,
            headers={"Authorization": "Bearer %s" % token},
            method="DELETE",
        )
        return resp.status_code, resp.json()

    def _make_notification(self, user=None, read=False, sequence=1):
        user = user or self.user
        return self.env["mobile.notification.log"].sudo().create({
            "user_id": user.id,
            "notification_type": "payslip_available",
            "res_model": "hr.payslip",
            "res_id": sequence,
            "status": "sent",
            "title": "Payslip Available",
            "message": "Your payslip for July 2026 is now available.",
            "data_json": json.dumps({
                "feature": "payslip",
                "payslip_id": sequence,
                "action": "open_payslip_detail",
            }),
            "read_at": "2026-07-01 00:00:00" if read else False,
        })

    def test_missing_token_returns_401(self):
        status, body = self._get()
        self.assertEqual(status, 401)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "missing_access_token")

    def test_fetch_scopes_to_current_user_and_marks_all_unread_read(self):
        own = self._make_notification(sequence=11)
        self._make_notification(self.other_user, sequence=99)
        token = self._token()

        status, body = self._get(token, page=1, limit=10)
        self.assertEqual(status, 200)
        self.assertTrue(body["success"])
        self.assertEqual(body["data"]["unread_count_before_fetch"], 1)
        self.assertEqual(len(body["data"]["notifications"]), 1)
        item = body["data"]["notifications"][0]
        self.assertEqual(item["id"], own.id)
        self.assertFalse(item["is_read"])
        self.assertEqual(item["title"], "Payslip Available")
        self.assertEqual(item["message"], "Your payslip for July 2026 is now available.")
        self.assertEqual(item["data"]["payslip_id"], 11)
        self.assertEqual(item["delivery_status"], "sent")

        self.assertTrue(own.sudo().read_at)

    def test_second_fetch_returns_notifications_as_read(self):
        self._make_notification(sequence=12)
        token = self._token()
        self._get(token)

        status, body = self._get(token)
        self.assertEqual(status, 200)
        self.assertEqual(body["data"]["unread_count_before_fetch"], 0)
        self.assertTrue(body["data"]["notifications"][0]["is_read"])
        self.assertTrue(body["data"]["notifications"][0]["read_at"])

    def test_pagination_marks_all_unread_not_only_current_page(self):
        """Fetching marks every notification read, not only the served page; this is intended product behaviour."""
        first = self._make_notification(sequence=1)
        second = self._make_notification(sequence=2)
        token = self._token()

        status, body = self._get(token, page=1, limit=1)
        self.assertEqual(status, 200)
        self.assertEqual(body["data"]["unread_count_before_fetch"], 2)
        self.assertEqual(len(body["data"]["notifications"]), 1)
        self.assertEqual(body["data"]["pagination"]["total"], 2)
        self.assertTrue(body["data"]["pagination"]["has_next"])
        self.assertTrue(first.sudo().read_at)
        self.assertTrue(second.sudo().read_at)

    def test_invalid_pagination_returns_400(self):
        token = self._token()
        status, body = self._get(token, page=0, limit=20)
        self.assertEqual(status, 400)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "invalid_pagination")

    def test_user_can_delete_own_notification(self):
        notification = self._make_notification(sequence=20)
        token = self._token()

        status, body = self._delete(notification.id, token)

        self.assertEqual(status, 200)
        self.assertTrue(body["success"])
        self.assertEqual(body["data"], {
            "id": notification.id,
            "deleted": True,
        })
        self.assertFalse(notification.sudo().exists())

    def test_user_cannot_delete_another_users_notification(self):
        other_notification = self._make_notification(
            user=self.other_user, sequence=21)
        token = self._token()

        status, body = self._delete(other_notification.id, token)

        self.assertEqual(status, 404)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "notification_not_found")
        self.assertTrue(other_notification.sudo().exists())
