from datetime import datetime, timedelta

from odoo.tests import HttpCase, tagged


@tagged("-at_install", "post_install")
class TestMobileActivityApi(HttpCase):
    """Tests for GET /api/mobile/v1/recent-activities."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        # Mobile users need base.group_user plus group_mobile_user for the non-sudo hr.* record rules.
        cls.user = Users.create({
            "name": "Activity Api User",
            "login": "activity_api_user@test.com",
            "password": "activity_api_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Activity Api User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })

        cls.other_user = Users.create({
            "name": "Activity Api Other User",
            "login": "activity_api_other@test.com",
            "password": "activity_api_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.other_employee = Employee.create({
            "name": "Activity Api Other User",
            "company_id": company.id,
            "user_id": cls.other_user.id,
        })

        cls.user_no_employee = Users.create({
            "name": "Activity Api No Employee",
            "login": "activity_api_noemp@test.com",
            "password": "activity_api_pw_1234",
            "group_ids": [(4, mobile_group.id)],
        })

        cls.leave_type = cls.env["hr.leave.type"].sudo().create({
            "name": "Activity Api Casual Leave",
            "requires_allocation": False,
            "company_id": company.id,
        })

    def _token_for(self, login, password):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": login, "password": password},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login unexpectedly failed: %s" % body)
        return body["data"]["token"]

    def _get(self, token, **params):
        resp = self.url_open(
            "/api/mobile/v1/recent-activities",
            headers={"Authorization": "Bearer %s" % token},
            params=params or None,
        )
        return resp.status_code, resp.json()

    def _make_leave(self, employee, days_ago=0):
        leave = self.env["hr.leave"].sudo().create({
            "employee_id": employee.id,
            "holiday_status_id": self.leave_type.id,
            "request_date_from": (datetime.now() - timedelta(days=days_ago)).date(),
            "request_date_to": (datetime.now() - timedelta(days=days_ago)).date(),
        })
        return leave

    def _make_attendance(self, employee, hours_ago=1):
        check_in = datetime.now() - timedelta(hours=hours_ago)
        return self.env["hr.attendance"].sudo().create({
            "employee_id": employee.id,
            "check_in": check_in,
            "check_out": check_in + timedelta(hours=1),
        })

    def test_mobile_user_can_fetch_home_recent_activities(self):
        self._make_leave(self.employee)
        token = self._token_for("activity_api_user@test.com", "activity_api_pw_1234")
        status, body = self._get(token, home="true")
        self.assertEqual(status, 200)
        self.assertTrue(body["success"])
        self.assertTrue(body["data"]["home"])
        self.assertTrue(len(body["data"]["items"]) >= 1)
        self.assertEqual(body["data"]["items"][0]["type"], "leave_requested")

    def test_home_returns_only_three_items(self):
        for days_ago in range(1, 11, 2):
            self._make_leave(self.employee, days_ago=days_ago)
        token = self._token_for("activity_api_user@test.com", "activity_api_pw_1234")
        status, body = self._get(token, home="true")
        self.assertEqual(status, 200)
        self.assertEqual(len(body["data"]["items"]), 3)
        self.assertNotIn("pagination", body["data"])

    def test_without_home_returns_paginated_list(self):
        for days_ago in range(1, 11, 2):
            self._make_leave(self.employee, days_ago=days_ago)
        token = self._token_for("activity_api_user@test.com", "activity_api_pw_1234")
        status, body = self._get(token, limit=2)
        self.assertEqual(status, 200)
        self.assertEqual(len(body["data"]["items"]), 2)
        pagination = body["data"]["pagination"]
        self.assertEqual(pagination["page"], 1)
        self.assertEqual(pagination["limit"], 2)
        self.assertEqual(pagination["total"], 5)
        self.assertTrue(pagination["has_next"])
        self.assertFalse(pagination["has_previous"])

    def test_newest_activity_appears_first(self):
        older = self._make_leave(self.employee, days_ago=20)
        newer = self._make_leave(self.employee, days_ago=10)
        # Force distinct create_date ordering; auto-stamped values can collide within a fast test.
        self.env.cr.execute(
            "UPDATE hr_leave SET create_date = %s, write_date = %s WHERE id = %s",
            (datetime.now() - timedelta(days=2), datetime.now() - timedelta(days=2), older.id),
        )
        self.env.cr.execute(
            "UPDATE hr_leave SET create_date = %s, write_date = %s WHERE id = %s",
            (datetime.now() - timedelta(days=1), datetime.now() - timedelta(days=1), newer.id),
        )
        token = self._token_for("activity_api_user@test.com", "activity_api_pw_1234")
        status, body = self._get(token)
        self.assertEqual(status, 200)
        items = body["data"]["items"]
        self.assertEqual(items[0]["source_id"], newer.id)
        self.assertEqual(items[1]["source_id"], older.id)

    def test_non_mobile_user_is_rejected(self):
        """Group removed after token issuance is still caught (defense in depth)."""
        token = self._token_for("activity_api_user@test.com", "activity_api_pw_1234")
        mobile_group = self.env.ref("odx_mobile_connector.group_mobile_user")
        self.user.sudo().write({"group_ids": [(3, mobile_group.id)]})
        status, body = self._get(token)
        self.assertEqual(status, 403)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "mobile_access_denied")

    def test_user_without_linked_employee_gets_safe_error(self):
        """A token whose employee was unlinked after login gets a clean 404, not a crash."""
        token = self._token_for("activity_api_user@test.com", "activity_api_pw_1234")
        self.employee.write({"user_id": False})
        self.env.flush_all()
        self.addCleanup(self.employee.write, {"user_id": self.user.id})
        status, body = self._get(token)
        self.assertEqual(status, 404)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "employee_not_found")

    def test_leave_activity_scoped_to_current_employee(self):
        self._make_leave(self.other_employee)
        token = self._token_for("activity_api_user@test.com", "activity_api_pw_1234")
        status, body = self._get(token)
        self.assertEqual(status, 200)
        self.assertEqual(body["data"]["items"], [])

    def test_expense_activity_scoped_to_current_employee(self):
        product = self.env["product.product"].sudo().create({
            "name": "Activity Api Expense Category",
            "type": "service",
            "can_be_expensed": True,
        })
        self.env["hr.expense"].sudo().create({
            "name": "Other user's expense",
            "employee_id": self.other_employee.id,
            "product_id": product.id,
            "total_amount_currency": 10.0,
        })
        token = self._token_for("activity_api_user@test.com", "activity_api_pw_1234")
        status, body = self._get(token, type="expense")
        self.assertEqual(status, 200)
        self.assertEqual(body["data"]["items"], [])

    def test_attendance_checkin_checkout_scoped_to_current_employee(self):
        self._make_attendance(self.other_employee)
        self._make_attendance(self.employee)
        token = self._token_for("activity_api_user@test.com", "activity_api_pw_1234")
        status, body = self._get(token, type="attendance")
        self.assertEqual(status, 200)
        items = body["data"]["items"]
        self.assertEqual(len(items), 2, "expected one checkin + one checkout for own employee only")
        self.assertEqual({i["type"] for i in items}, {"checkin_created", "checkout_created"})

    def test_feature_access_excludes_denied_activity(self):
        self._make_leave(self.employee)
        expense_feature = self.env.ref("odx_mobile_connector.feature_expense",
                                       raise_if_not_found=False)
        leave_feature = self.env.ref("odx_mobile_connector.feature_leave",
                                     raise_if_not_found=False)
        feature = expense_feature or leave_feature
        if not feature:
            self.skipTest("No default mobile.feature record found to restrict.")
        # Access is deny-by-default: joining the group auto-creates link rows, removing one revokes.
        self.env["mobile.user.feature"].sudo().search([
            ("user_id", "=", self.user.id), ("feature_id", "=", feature.id),
        ]).unlink()
        token = self._token_for("activity_api_user@test.com", "activity_api_pw_1234")
        restricted_type = "expense" if feature == expense_feature else "leave"
        status, body = self._get(token, type=restricted_type)
        self.assertEqual(status, 200)
        self.assertEqual(body["data"]["items"], [])

    def test_invalid_page_returns_safe_error(self):
        token = self._token_for("activity_api_user@test.com", "activity_api_pw_1234")
        status, body = self._get(token, page=0)
        self.assertEqual(status, 400)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "invalid_page")

    def test_invalid_limit_returns_safe_error(self):
        token = self._token_for("activity_api_user@test.com", "activity_api_pw_1234")
        status, body = self._get(token, limit=0)
        self.assertEqual(status, 400)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "invalid_limit")

    def test_invalid_type_returns_safe_error(self):
        token = self._token_for("activity_api_user@test.com", "activity_api_pw_1234")
        status, body = self._get(token, type="not_a_real_type")
        self.assertEqual(status, 400)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "invalid_type")

    def test_controller_does_not_use_broad_sudo(self):
        """Static guard: the aggregation logic must stay sudo-free (only the
        API-key credential check, common to every endpoint, may use sudo())."""
        import inspect

        from odoo.addons.odx_mobile_api.controllers import activity as activity_module
        source = inspect.getsource(activity_module)
        sudo_lines = [line for line in source.splitlines() if "sudo(" in line]
        self.assertEqual(
            len(sudo_lines), 1,
            "Unexpected sudo() usage in activity.py: %s" % sudo_lines,
        )
        self.assertIn("_check_credentials", sudo_lines[0])
