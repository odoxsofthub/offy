from datetime import date

from odoo.tests import HttpCase, tagged

LOGIN = "expense_currency_user@test.com"
PASSWORD = "expense_currency_pw_1234"

# Deliberately not 1.0: at a 1:1 rate the assertions pass whichever field the payload reads.
USD_PER_COMPANY_UNIT = 4.0


@tagged("-at_install", "post_install")
class TestExpenseCurrencyLabelling(HttpCase):
    """Expense amounts must be in the company currency named by the payload's `currency` block.
    So payloads use `total_amount`, not the expense-currency `total_amount_currency`."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        Product = cls.env["product.product"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        cls.company = cls.env.ref("base.main_company")

        # Any currency other than the company's; EUR when the company itself is on USD.
        usd = cls.env.ref("base.USD").sudo()
        cls.foreign_currency = usd if usd != cls.company.currency_id else cls.env.ref("base.EUR").sudo()
        cls.foreign_currency.active = True
        # Wipe any pre-existing rate for the window so the fixture, not the host database, decides.
        cls.env["res.currency.rate"].sudo().search([
            ("currency_id", "=", cls.foreign_currency.id),
            ("company_id", "in", [False, cls.company.id]),
        ]).unlink()
        cls.env["res.currency.rate"].sudo().create({
            "currency_id": cls.foreign_currency.id,
            "company_id": cls.company.id,
            "name": "2000-01-01",
            "rate": USD_PER_COMPANY_UNIT,
        })

        cls.category = Product.create({
            "name": "Currency Probe Travel", "type": "service",
            "can_be_expensed": True})
        cls.user = Users.create({
            "name": "Currency Probe User",
            "login": LOGIN,
            "password": PASSWORD,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Currency Probe User", "company_id": cls.company.id,
            "user_id": cls.user.id})
        cls.today = date.today()

    def _foreign_expense(self, amount_in_usd):
        expense = self.env["hr.expense"].sudo().create({
            "name": "Foreign claim %s" % amount_in_usd,
            "employee_id": self.employee.id,
            "product_id": self.category.id,
            "quantity": 1,
            "currency_id": self.foreign_currency.id,
            "total_amount_currency": amount_in_usd,
            "date": self.today,
            "payment_mode": "own_account",
        })
        self.assertNotAlmostEqual(
            expense.total_amount, expense.total_amount_currency, places=2,
            msg="fixture is useless unless the two figures differ")
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

    def _get(self, path):
        resp = self.url_open(
            path, headers={"Authorization": "Bearer %s" % self._token()})
        body = resp.json()
        self.assertTrue(body["success"], body)
        return body["data"]

    def test_list_amount_is_in_the_currency_the_payload_names(self):
        expense = self._foreign_expense(100.0)
        data = self._get("/api/mobile/v1/expense?limit=50")
        rows = [e for g in data["groups"] for e in g["expenses"]]
        row = next(r for r in rows if r["id"] == expense.id)
        self.assertEqual(row["currency"], self.company.currency_id.name,
                         "sanity: the payload labels this company-currency")
        self.assertAlmostEqual(row["amount"], expense.total_amount, places=2)
        self.assertNotAlmostEqual(
            row["amount"], expense.total_amount_currency, places=2,
            msg="the amount is still the expense's own-currency figure")

    def test_summary_recent_expenses_use_the_same_figure(self):
        """`/expense/summary` serialises through the same `_expense_payload`,
        so it must not disagree with the list about what an amount means."""
        expense = self._foreign_expense(100.0)
        data = self._get("/api/mobile/v1/expense/summary")
        row = next(r for r in data["recent_expenses"] if r["id"] == expense.id)
        self.assertAlmostEqual(row["amount"], expense.total_amount, places=2)

    def test_home_card_total_is_a_single_denomination(self):
        """The home card total sums company-currency amounts, not mixed denominations."""
        foreign = self._foreign_expense(100.0)
        self.env["hr.expense"].sudo().create({
            "name": "Domestic claim",
            "employee_id": self.employee.id,
            "product_id": self.category.id,
            "quantity": 1,
            "total_amount_currency": 40.0,
            "date": self.today,
            "payment_mode": "own_account",
        })
        card = self._get("/api/mobile/v1/home")["home"]["expense"]
        self.assertEqual(card["currency"]["name"],
                         self.company.currency_id.name)
        self.assertAlmostEqual(
            card["total_amount"], foreign.total_amount + 40.0, places=2)

    def test_activity_feed_amount_is_company_currency(self):
        expense = self._foreign_expense(100.0)
        items = self._get("/api/mobile/v1/recent-activities")["items"]
        rows = [i for i in items if expense.name in (i.get("subtitle") or "")]
        self.assertTrue(rows, "the new expense should be in the feed: %s" % items)
        # `_format_amount` uses the company currency symbol, so the figure must be the company-currency one.
        expected = "%.2f" % expense.total_amount
        unconverted = "%.2f" % expense.total_amount_currency
        subtitle = rows[0]["subtitle"]
        self.assertIn(expected, subtitle, subtitle)
        self.assertNotIn("%s%s" % (self.company.currency_id.symbol, unconverted),
                         subtitle, subtitle)
