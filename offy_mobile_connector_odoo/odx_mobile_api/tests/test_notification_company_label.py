import json
from datetime import date, timedelta
from unittest.mock import patch

from odoo.tests import HttpCase, TransactionCase, tagged

from ..notifications import COMPANY_TITLE_SEPARATOR, NOTIFICATION_TITLES

PASSWORD = "notif_company_pw_1234"
MULTI_LOGIN = "notif_company_multi@test.com"


def _next_monday():
    today = date.today()
    return today + timedelta(days=(7 - today.weekday()) % 7 or 7)


class CompanyLabelFixture:
    """Two companies and three users; `permitted_user` has both in `company_ids` but is employed in one.
    The switcher lists employment, so that user must get no company label."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        groups = [(4, mobile_group.id), (4, internal_group.id)]

        cls.company_a = cls.env.ref("base.main_company")
        cls.company_b = cls.env["res.company"].sudo().create(
            {"name": "Notif Label Company B"})

        # Employed in BOTH -> the app shows a switcher.
        cls.multi_user = Users.create({
            "name": "Notif Company Multi",
            "login": MULTI_LOGIN,
            "password": PASSWORD,
            "company_id": cls.company_a.id,
            "company_ids": [(6, 0, [cls.company_a.id, cls.company_b.id])],
            "group_ids": groups,
        })
        cls.multi_employee_a = Employee.create({
            "name": "Notif Company Multi",
            "company_id": cls.company_a.id,
            "user_id": cls.multi_user.id,
        })
        cls.multi_employee_b = Employee.create({
            "name": "Notif Company Multi",
            "company_id": cls.company_b.id,
            "user_id": cls.multi_user.id,
        })

        # Employed in ONE -> no switcher, nothing to disambiguate.
        cls.single_user = Users.create({
            "name": "Notif Company Single",
            "login": "notif_company_single@test.com",
            "password": PASSWORD,
            "company_id": cls.company_a.id,
            "company_ids": [(6, 0, [cls.company_a.id])],
            "group_ids": groups,
        })
        cls.single_employee = Employee.create({
            "name": "Notif Company Single",
            "company_id": cls.company_a.id,
            "user_id": cls.single_user.id,
        })

        # Permitted into two, employed in one.
        cls.permitted_user = Users.create({
            "name": "Notif Company Permitted",
            "login": "notif_company_permitted@test.com",
            "password": PASSWORD,
            "company_id": cls.company_a.id,
            "company_ids": [(6, 0, [cls.company_a.id, cls.company_b.id])],
            "group_ids": groups,
        })
        cls.permitted_employee = Employee.create({
            "name": "Notif Company Permitted",
            "company_id": cls.company_a.id,
            "user_id": cls.permitted_user.id,
        })

        cls.category = cls.env["product.product"].sudo().create({
            "name": "Notif Label Travel", "type": "service",
            "can_be_expensed": True})
        cls.leave_type = cls.env["hr.leave.type"].sudo().create({
            "name": "Notif Label Leave",
            "requires_allocation": False,
            "request_unit": "day",
            "leave_validation_type": "hr",
        })

    def _expense(self, employee):
        return self.env["hr.expense"].sudo().create({
            "name": "Company label claim",
            "employee_id": employee.id,
            "company_id": employee.company_id.id,
            "product_id": self.category.id,
            "quantity": 1,
            "total_amount_currency": 42.0,
            "date": "2026-06-29",
            "payment_mode": "own_account",
        })

    def _payslip(self, employee):
        return self.env["hr.payslip"].sudo().create({
            "employee_id": employee.id,
            "company_id": employee.company_id.id,
            "name": "Company label payslip",
            "date_from": date(2026, 6, 1),
            "date_to": date(2026, 6, 30),
        })

    def _leave(self, employee):
        day = _next_monday()
        return self.env["hr.leave"].sudo().create({
            "employee_id": employee.id,
            "holiday_status_id": self.leave_type.id,
            "request_date_from": day,
            "request_date_to": day,
        })

    def _queued(self, mutate):
        """Run *mutate*, returning every notification it would have queued."""
        with patch.object(
            type(self.env["mobile.push.service"]), "queue_once_to_user"
        ) as queue_mock:
            mutate()
        self.assertTrue(queue_mock.called, "no notification was queued")
        calls = []
        for args, kwargs in queue_mock.call_args_list:
            calls.append({
                "user": args[0],
                "type": args[1],
                "title": args[4],
                "body": args[5],
                "data": kwargs.get("data") or {},
            })
        return calls

    def _queued_one(self, mutate):
        calls = self._queued(mutate)
        self.assertEqual(len(calls), 1, "expected exactly one: %s" % calls)
        return calls[0]


@tagged("post_install", "-at_install")
class TestNotificationCompanyLabel(CompanyLabelFixture, TransactionCase):
    """A notification names the company its record belongs to, so a multi-company user knows where to look."""

    def test_multi_company_user_has_a_switcher(self):
        self.assertEqual(
            sorted(self.multi_user._mobile_company_ids()),
            sorted([self.company_a.id, self.company_b.id]))
        self.assertTrue(self.multi_user._mobile_is_multi_company())

    def test_permission_without_employment_is_not_multi_company(self):
        """Two companies in `company_ids` but employed in one is not multi-company."""
        self.assertEqual(len(self.permitted_user.company_ids), 2)
        self.assertEqual(self.permitted_user._mobile_company_ids(),
                         [self.company_a.id])
        self.assertFalse(self.permitted_user._mobile_is_multi_company())

    def test_single_company_user_is_not_multi_company(self):
        self.assertFalse(self.single_user._mobile_is_multi_company())

    def test_expense_notification_names_the_company(self):
        expense = self._expense(self.multi_employee_b)
        queued = self._queued_one(
            lambda: expense.write({"approval_state": "approved"}))
        self.assertTrue(
            queued["title"].endswith(
                "%s%s" % (COMPANY_TITLE_SEPARATOR, self.company_b.name)),
            queued["title"])
        self.assertEqual(queued["data"]["company_id"], self.company_b.id)
        self.assertEqual(queued["data"]["company_name"], self.company_b.name)

    def test_label_is_the_records_company_not_the_users_default(self):
        """The label uses the record's company, not the user's default company."""
        self.assertEqual(self.multi_user.company_id, self.company_a)
        expense = self._expense(self.multi_employee_b)
        queued = self._queued_one(
            lambda: expense.write({"approval_state": "approved"}))
        self.assertIn(self.company_b.name, queued["title"])
        self.assertNotIn(self.company_a.name, queued["title"])

    def test_single_company_user_gets_no_label(self):
        expense = self._expense(self.single_employee)
        queued = self._queued_one(
            lambda: expense.write({"approval_state": "approved"}))
        self.assertNotIn(COMPANY_TITLE_SEPARATOR, queued["title"])
        self.assertEqual(queued["title"], "Expense Approved")

    def test_permitted_but_unemployed_company_earns_no_label(self):
        """End-to-end `company_ids` trap: permitted in two companies, employed in one, gets no label."""
        expense = self._expense(self.permitted_employee)
        queued = self._queued_one(
            lambda: expense.write({"approval_state": "approved"}))
        self.assertEqual(queued["title"], "Expense Approved")
        self.assertNotIn(COMPANY_TITLE_SEPARATOR, queued["title"])

    def test_company_is_in_data_even_without_a_label(self):
        """`company` in the data payload is unconditional, label or not."""
        expense = self._expense(self.single_employee)
        queued = self._queued_one(
            lambda: expense.write({"approval_state": "approved"}))
        self.assertEqual(queued["data"]["company_id"], self.company_a.id)
        self.assertEqual(queued["data"]["company_name"], self.company_a.name)

    def test_refused_expense_is_labelled_too(self):
        """Not just the happy path -- "All actions", per the request."""
        expense = self._expense(self.multi_employee_b)
        queued = self._queued_one(
            lambda: expense.write({"approval_state": "refused"}))
        self.assertTrue(queued["title"].startswith("Expense Refused"))
        self.assertIn(self.company_b.name, queued["title"])

    def test_payslip_notification_names_the_company(self):
        payslip = self._payslip(self.multi_employee_b)
        queued = self._queued_one(
            lambda: payslip.write({"state": "validated"}))
        self.assertTrue(queued["title"].startswith("Payslip Available"))
        self.assertIn(self.company_b.name, queued["title"])
        self.assertEqual(queued["data"]["company_id"], self.company_b.id)

    def test_payslip_for_the_other_company_names_that_one(self):
        """Both payslips exist; each must name its own payer."""
        payslip_a = self._payslip(self.multi_employee_a)
        queued = self._queued_one(
            lambda: payslip_a.write({"state": "validated"}))
        self.assertIn(self.company_a.name, queued["title"])
        self.assertNotIn(self.company_b.name, queued["title"])

    def test_timeoff_notification_names_the_company(self):
        leave = self._leave(self.multi_employee_b)
        queued = self._queued_one(lambda: leave.write({"state": "validate"}))
        self.assertTrue(queued["title"].startswith("Time Off Approved"))
        self.assertIn(self.company_b.name, queued["title"])
        self.assertEqual(queued["data"]["company_id"], self.company_b.id)

    def test_the_body_is_not_touched(self):
        """The label goes in the title only, never the body."""
        expense = self._expense(self.multi_employee_b)
        queued = self._queued_one(
            lambda: expense.write({"approval_state": "approved"}))
        self.assertNotIn(COMPANY_TITLE_SEPARATOR, queued["body"])

    def test_every_catalogued_type_is_labelled(self):
        """Every type in `NOTIFICATION_TITLES` is labelled, via `_queue_mobile_notification` directly."""
        expense = self._expense(self.multi_employee_b)
        unlabelled = []
        for notification_type, default_title in sorted(NOTIFICATION_TITLES.items()):
            queued = self._queued_one(lambda t=notification_type, d=default_title: (
                expense._queue_mobile_notification(
                    self.multi_employee_b, "expense", t, d, "body",
                    dedup_key="label-probe:%s" % t)
            ))
            expected = "%s%s%s" % (
                default_title, COMPANY_TITLE_SEPARATOR, self.company_b.name)
            if queued["title"] != expected:
                unlabelled.append((notification_type, queued["title"]))
            if queued["data"].get("company_id") != self.company_b.id:
                unlabelled.append((notification_type, "no company_id in data"))
        self.assertEqual(
            unlabelled, [],
            "these catalogued types did not carry the company: %s" % unlabelled)


@tagged("post_install", "-at_install")
class TestNotificationCompanyLabelApi(CompanyLabelFixture, HttpCase):
    """The label survives to the `/notifications` inbox payload (also the push title)."""

    def _token(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": MULTI_LOGIN, "password": PASSWORD},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"]

    def _inbox(self):
        resp = self.url_open(
            "/api/mobile/v1/notifications?limit=50",
            headers={"Authorization": "Bearer %s" % self._token()})
        body = resp.json()
        self.assertTrue(body["success"], body)
        return body["data"]["notifications"]

    def test_inbox_shows_the_label_and_a_company_block(self):
        expense = self._expense(self.multi_employee_b)
        expense.write({"approval_state": "approved"})
        self.env.flush_all()

        rows = [r for r in self._inbox() if r["type"] == "expense_approved"]
        self.assertTrue(rows, "the notification never reached the inbox")
        row = rows[0]
        self.assertIn(self.company_b.name, row["title"])
        self.assertEqual(row["company"], {
            "id": self.company_b.id, "name": self.company_b.name})
        self.assertEqual(row["data"]["company_id"], self.company_b.id)

    def test_a_row_queued_before_this_change_still_renders(self):
        """Rows queued without `company_id` in `data_json` still render, with `company` absent."""
        log = self.env["mobile.notification.log"].sudo().create({
            "user_id": self.multi_user.id,
            "notification_type": "expense_approved",
            "res_model": "hr.expense",
            "res_id": 0,
            "status": "pending",
            "title": "Expense Approved",
            "message": "Legacy row",
            "data_json": json.dumps({"type": "expense_approved"}),
        })
        self.env.flush_all()
        rows = [r for r in self._inbox() if r["id"] == log.id]
        self.assertEqual(len(rows), 1, "the legacy row vanished")
        self.assertIsNone(rows[0]["company"])
        self.assertEqual(rows[0]["title"], "Expense Approved")
