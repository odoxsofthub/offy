from datetime import date, timedelta
from unittest.mock import patch

from odoo.tests import HttpCase, tagged

LOGIN = "home_card_user@test.com"
PASSWORD = "home_card_pw_1234"


@tagged("-at_install", "post_install")
class TestMobileHomeExpenseCard(HttpCase):
    """The home Expense card total excludes refused claims.
    So a refusal must trigger a realtime home sync."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        Product = cls.env["product.product"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.category = Product.create({
            "name": "Home Card Travel", "type": "service",
            "can_be_expensed": True})

        cls.user = Users.create({
            "name": "Home Card User",
            "login": LOGIN,
            "password": PASSWORD,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Home Card User", "company_id": company.id,
            "user_id": cls.user.id})

        # Anchored to today so it always lands in the card's current-month window (employee tz).
        cls.today = date.today()

    def _expense(self, amount, state=None, on=None):
        """One expense for this employee, forced into *state* via `approval_state` (state is computed)."""
        expense = self.env["hr.expense"].sudo().create({
            "name": "Home card %s" % amount,
            "employee_id": self.employee.id,
            "product_id": self.category.id,
            "quantity": 1,
            "total_amount_currency": amount,
            "date": on or self.today,
            "payment_mode": "own_account",
        })
        if state:
            expense.write({"approval_state": state})
        return expense

    def _token(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": LOGIN, "password": PASSWORD},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"]

    def _card(self, token=None):
        resp = self.url_open(
            "/api/mobile/v1/home",
            headers={"Authorization": "Bearer %s" % (token or self._token())})
        body = resp.json()
        self.assertTrue(body["success"], body)
        return body["data"]["home"]["expense"]

    def test_refused_expense_is_not_counted(self):
        """The report: a rejected claim still showed up in the card total."""
        self._expense(90.0)
        refused = self._expense(100.0, state="refused")
        self.assertEqual(refused.state, "refused", "sanity: it really is refused")

        card = self._card()
        self.assertEqual(card["total_amount"], 90.0,
                         "the refused 100.00 must not be in the total")

    def test_refusing_an_expense_removes_it_from_the_total(self):
        """The transition itself, not just a record that starts out refused."""
        expense = self._expense(100.0)
        self.assertEqual(self._card()["total_amount"], 100.0)

        expense.write({"approval_state": "refused"})
        self.assertEqual(self._card()["total_amount"], 0.0,
                         "refusing it should take the amount off the card")

    def test_every_other_state_still_counts(self):
        """Only `refused` is excluded. Draft and pending are claims in
        flight, approved and paid are real money -- all still spending."""
        self._expense(10.0)                        # draft
        self._expense(20.0, state="submitted")
        self._expense(30.0, state="approved")
        self._expense(40.0, state="refused")

        card = self._card()
        self.assertEqual(card["total_amount"], 60.0,
                         "10 + 20 + 30, with the refused 40 left out")

    def test_a_refused_expense_in_another_month_changes_nothing(self):
        """Guards the pre-existing month window while adding the state
        filter -- the two conditions are independent."""
        self._expense(50.0)
        last_month = self.today.replace(day=1) - timedelta(days=1)
        self._expense(500.0, state="refused", on=last_month)
        self.assertEqual(self._card()["total_amount"], 50.0)

    def test_refusing_an_expense_triggers_a_home_sync(self):
        """Refusing syncs the card even though `state`, being computed, never appears in `write()` vals."""
        expense = self._expense(100.0)
        with patch.object(
            type(self.env["mobile.sync.service"]), "notify_home"
        ) as sync:
            expense.write({"approval_state": "refused"})
        self.assertTrue(
            sync.called,
            "refusing an expense must sync the home card, or the phone keeps "
            "showing a total that still includes it")
        users = sync.call_args[0][0]
        self.assertIn(self.user, users,
                      "the owning employee's user must be notified")

    def test_approving_an_expense_also_syncs(self):
        """Approving also syncs, since it can reinstate a refused claim."""
        expense = self._expense(100.0)
        with patch.object(
            type(self.env["mobile.sync.service"]), "notify_home"
        ) as sync:
            expense.write({"approval_state": "approved"})
        self.assertTrue(sync.called)

    def test_editing_the_amount_still_syncs(self):
        """Amount edits through `write()` still sync."""
        expense = self._expense(100.0)
        with patch.object(
            type(self.env["mobile.sync.service"]), "notify_home"
        ) as sync:
            expense.write({"total_amount_currency": 250.0})
        self.assertTrue(sync.called)
