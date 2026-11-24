from odoo.tests import TransactionCase, tagged

from ..controllers.expense import expense_payment_payload


@tagged("post_install", "-at_install")
class TestExpensePaymentAllocations(TransactionCase):
    """`amount_paid` and per-payment amounts must match the reconciled allocation, not payment face value.
    Fixture reconciles three payments one at a time so the last is only partly applied."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        Product = cls.env["product.product"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        company = cls.env.ref("base.main_company")

        cls.category = Product.create({
            "name": "Payment Allocation Travel", "type": "service",
            "can_be_expensed": True})
        cls.user = Users.create({
            "name": "Payment Allocation Employee",
            "login": "payment_allocation_user@test.com",
            "group_ids": [(4, mobile_group.id), (4, cls.env.ref("base.group_user").id)],
        })
        cls.employee = Employee.create({
            "name": "Payment Allocation Employee",
            "company_id": company.id,
            "user_id": cls.user.id,
        })
        cls.partner = cls.env["res.partner"].create({"name": "Payment Allocation Vendor"})

        cls.payable_account = cls.env["account.account"].search([
            ("account_type", "=", "liability_payable"),
            ("company_ids", "in", company.id),
        ], limit=1)
        cls.expense_account = cls.env["account.account"].search([
            ("account_type", "=", "expense"),
            ("company_ids", "in", company.id),
        ], limit=1)
        cls.general_journal = cls.env["account.journal"].search([
            ("type", "=", "general"), ("company_id", "=", company.id)], limit=1)
        cls.bank_journal = cls.env["account.journal"].search([
            ("type", "in", ("bank", "cash")), ("company_id", "=", company.id)], limit=1)

        cls.expense = cls.env["hr.expense"].sudo().create({
            "name": "Payment Allocation Expense",
            "employee_id": cls.employee.id,
            "product_id": cls.category.id,
            "quantity": 1,
            "total_amount_currency": 120.0,
            "date": "2026-06-01",
            "payment_mode": "own_account",
        })

        # Bill move built directly, not via the approve/post workflow, which this suite is not about.
        bill = cls.env["account.move"].sudo().create({
            "journal_id": cls.general_journal.id,
            "date": "2026-06-01",
            "move_type": "entry",
            "line_ids": [
                (0, 0, {"account_id": cls.expense_account.id, "partner_id": cls.partner.id,
                        "debit": 120.0, "credit": 0.0, "name": "Payment Allocation Expense"}),
                (0, 0, {"account_id": cls.payable_account.id, "partner_id": cls.partner.id,
                        "debit": 0.0, "credit": 120.0, "name": "Payment Allocation Payable"}),
            ],
        })
        bill.action_post()
        cls.bill_payable_line = bill.line_ids.filtered(
            lambda l: l.account_id == cls.payable_account)

        cls.expense.sudo().write({"account_move_id": bill.id})
        cls.env.cr.execute(
            "UPDATE hr_expense SET state = 'paid' WHERE id = %s", [cls.expense.id])
        cls.env.invalidate_all()

        # Real payments (for origin_payment_id), reconciled one at a time against the shrinking balance.
        for amount in (50.0, 60.0, 30.0):
            payment = cls.env["account.payment"].sudo().create({
                "payment_type": "outbound",
                "partner_type": "supplier",
                "partner_id": cls.partner.id,
                "amount": amount,
                "journal_id": cls.bank_journal.id,
                "destination_account_id": cls.payable_account.id,
                "date": "2026-06-01",
            })
            payment.action_post()
            payment_line = payment.move_id.line_ids.filtered(
                lambda l: l.account_id == cls.payable_account)
            (cls.bill_payable_line + payment_line).reconcile()

    def test_the_ledger_fixture_matches_the_reported_shape(self):
        """Precondition: the fixture still reproduces the partly-applied payment shape."""
        self.assertTrue(self.bill_payable_line.reconciled)
        self.assertEqual(self.bill_payable_line.amount_residual, 0.0)
        third_payment_line = self.env["account.move.line"].search([
            ("account_id", "=", self.payable_account.id),
            ("debit", "=", 30.0),
            ("partner_id", "=", self.partner.id),
        ], order="id desc", limit=1)
        self.assertEqual(third_payment_line.amount_residual, 20.0)
        self.assertFalse(third_payment_line.reconciled)

    def test_payment_amounts_reflect_the_allocation_not_the_face_value(self):
        """The regression itself."""
        payload = expense_payment_payload(self.expense.sudo())
        amounts = [p["amount"] for p in payload["payments"]]
        self.assertEqual(
            amounts, [50.0, 60.0, 10.0],
            "each payment's reported amount must be what actually landed on "
            "this expense, not the payment's own total")

    def test_per_payment_amounts_sum_to_amount_paid(self):
        """The user-visible symptom: the breakdown must add up to the total."""
        payload = expense_payment_payload(self.expense.sudo())
        total_of_list = sum(p["amount"] for p in payload["payments"])
        self.assertEqual(total_of_list, payload["amount_paid"])
        self.assertEqual(payload["amount_paid"], 120.0)
        self.assertEqual(payload["total_amount"], 120.0)

    def test_third_payments_id_is_still_the_real_payment(self):
        """Only the AMOUNT is corrected -- identity, date, memo are unchanged."""
        payload = expense_payment_payload(self.expense.sudo())
        third = payload["payments"][2]
        expected_payment = self.env["account.payment"].search(
            [("amount", "=", 30.0), ("partner_id", "=", self.partner.id)],
            order="id desc", limit=1)
        self.assertEqual(third["id"], expected_payment.id)

    def test_allocations_helper_matches_the_controller(self):
        """The model helper and the controller must not drift apart."""
        allocations = self.expense.sudo()._mobile_payment_allocations()
        amounts = [amount for _payment, amount, _date, _amount_currency in allocations]
        self.assertEqual(amounts, [50.0, 60.0, 10.0])

    def test_amount_due_reaches_zero_once_fully_reconciled(self):
        """Amount due reaches zero once fully reconciled.
        `payment_state` is not asserted: Odoo does not compute it for `entry` moves."""
        payload = expense_payment_payload(self.expense.sudo())
        self.assertEqual(payload["amount_due"], 0.0)
