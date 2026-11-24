from unittest.mock import patch

from odoo.tests import HttpCase, TransactionCase, tagged

from ..models.hr_expense import _created_date_display, _created_date_iso, _money

PASSWORD = "expense_notif_date_pw_1234"


@tagged("post_install", "-at_install")
class TestExpenseNotificationCreatedDate(TransactionCase):
    """Expense notifications state the created date and amount in one sentence (trigger mocked).
    The payment trigger keeps its own received/pending message shape."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.user = cls.env["res.users"].create({
            "name": "Expense Notif Date User",
            "login": "expense_notif_date_user@test.com",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = cls.env["hr.employee"].create({
            "name": "Expense Notif Date User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })
        cls.category = cls.env["product.product"].create({
            "name": "Notif Date Travel", "type": "service", "can_be_expensed": True})

    def _make_expense(self):
        return self.env["hr.expense"].create({
            "name": "Notification Date Test",
            "employee_id": self.employee.id,
            "product_id": self.category.id,
            "quantity": 1,
            "total_amount_currency": 42.0,
            "date": "2026-06-29",
            "payment_mode": "own_account",
        })

    def _queued(self, mutate):
        """Run *mutate* and capture what would have been queued.
        Writes `approval_state`, since `state` is computed and writing it is silently ignored."""
        with patch.object(
            type(self.env["mobile.push.service"]), "queue_once_to_user"
        ) as send_mock:
            mutate()
        self.assertTrue(send_mock.called, "no notification was queued")
        args, kwargs = send_mock.call_args
        return {
            "title": args[4],
            "body": args[5],
            "data": kwargs.get("data") or {},
        }

    def _company_currency(self, expense):
        return expense.company_currency_id or expense.currency_id

    def test_approved_notification_is_the_natural_sentence(self):
        """The exact template requested: "<name>: Your expense of <amount>
        created at <date> has been approved."."""
        expense = self._make_expense()
        currency = self._company_currency(expense)
        expected = "%s: Your expense of %s created at %s has been approved." % (
            expense.name, _money(expense.total_amount, currency),
            _created_date_display(expense))
        sent = self._queued(lambda: expense.write({"approval_state": "approved"}))
        self.assertEqual(sent["body"], expected)

    def test_approved_notification_data_carries_amount_and_created_date(self):
        expense = self._make_expense()
        currency = self._company_currency(expense)
        sent = self._queued(lambda: expense.write({"approval_state": "approved"}))
        self.assertEqual(sent["data"]["created_date"], _created_date_iso(expense))
        self.assertEqual(sent["data"]["amount"], expense.total_amount)
        self.assertEqual(sent["data"]["amount_display"],
                         _money(expense.total_amount, currency))
        self.assertEqual(sent["data"]["currency"], currency.name)

    def test_refused_notification_is_the_natural_sentence_with_refused_verb(self):
        """Same template, only the verb changes -- proves the sentence isn't
        hardcoded to "approved" specifically."""
        expense = self._make_expense()
        currency = self._company_currency(expense)
        expected = "%s: Your expense of %s created at %s has been refused." % (
            expense.name, _money(expense.total_amount, currency),
            _created_date_display(expense))
        sent = self._queued(lambda: expense.write({"approval_state": "refused"}))
        self.assertEqual(sent["body"], expected)
        self.assertIsNotNone(sent["data"]["created_date"])
        self.assertEqual(sent["data"]["amount"], expense.total_amount)

    def test_long_expense_name_is_still_truncated(self):
        """The new sentence must not lose the pre-existing NAME_MAX_CHARS
        safeguard (a push banner shows roughly two lines)."""
        expense = self._make_expense()
        expense.write({"name": "A very long expense description that goes on "
                               "and on well past the truncation limit"})
        sent = self._queued(lambda: expense.write({"approval_state": "approved"}))
        self.assertTrue(sent["body"].startswith(
            "A very long expense description that goes on...: "),
            sent["body"])

    def test_payment_notification_names_the_created_date(self):
        """The reconciliation-driven payment trigger carries the same created-date detail.
        Allocations are mocked; only the payment's id is read."""
        expense = self._make_expense()
        expected = _created_date_display(expense)

        payment = self.env["account.payment"].create({
            "payment_type": "outbound", "partner_type": "supplier",
            "partner_id": self.env["res.partner"].create({"name": "Payee"}).id,
            "amount": 42.0,
            "journal_id": self.env["account.journal"].search(
                [("type", "in", ("bank", "cash"))], limit=1).id,
            "date": "2026-06-29",
        })

        with patch.object(
            type(expense), "_mobile_payment_allocations",
            return_value=[(payment, 42.0, None, 42.0)],
        ):
            sent = self._queued(lambda: expense._notify_mobile_expense_payments())
        self.assertIn("(created %s)" % expected, sent["body"])
        self.assertEqual(sent["data"]["created_date"], _created_date_iso(expense))


@tagged("-at_install", "post_install")
class TestExpenseNotificationCreatedDateApi(HttpCase):
    """End-to-end: `created_date` reaches the real `/notifications` JSON response."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.user = cls.env["res.users"].create({
            "name": "Expense Notif Date Api User",
            "login": "expense_notif_date_api@test.com",
            "password": PASSWORD,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = cls.env["hr.employee"].create({
            "name": "Expense Notif Date Api User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })

    def _token(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": "expense_notif_date_api@test.com", "password": PASSWORD},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], body)
        return body["data"]["token"]

    def test_created_date_round_trips_through_the_notifications_endpoint(self):
        import json as _json
        self.env["mobile.notification.log"].sudo().create({
            "user_id": self.user.id,
            "notification_type": "expense_approved",
            "res_model": "hr.expense",
            "res_id": 1,
            "status": "sent",
            "title": "Expense Approved",
            "message": "Client dinner: Your expense of ₹75.50 created at "
                       "September 2, 2026 has been approved.",
            "data_json": _json.dumps({
                "feature": "expense",
                "expense_id": 1,
                "state": "approved",
                "created_date": "2026-09-02T11:52:07Z",
                "amount": 75.5,
                "amount_display": "₹75.50",
                "currency": "INR",
                "action": "open_expense_detail",
            }),
        })
        token = self._token()
        resp = self.url_open(
            "/api/mobile/v1/notifications?page=1&limit=20",
            headers={"Authorization": "Bearer %s" % token})
        body = resp.json()
        self.assertEqual(resp.status_code, 200, body)
        notif = body["data"]["notifications"][0]
        self.assertEqual(
            notif["message"],
            "Client dinner: Your expense of ₹75.50 created at "
            "September 2, 2026 has been approved.")
        self.assertEqual(notif["data"]["created_date"], "2026-09-02T11:52:07Z")
        self.assertEqual(notif["data"]["amount"], 75.5)
        self.assertEqual(notif["data"]["amount_display"], "₹75.50")
