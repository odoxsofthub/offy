from unittest.mock import patch

from odoo.tests import TransactionCase, tagged

from ..controllers.expense import expense_payment_payload
from ..notifications import EXPENSE_PAID, EXPENSE_PARTIALLY_PAID


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


@tagged("post_install", "-at_install")
class TestSplitExpenseMirrorsOdoo(TransactionCase):
    """A split claim posted together shares ONE Odoo journal entry; the app must report Odoo's own
    figures for it (entry residual and payment state), not a per-half recalculation."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        company = cls.env.ref("base.main_company")
        cls.user = cls.env["res.users"].sudo().create({
            "name": "Split Claim Employee",
            "login": "split_claim_user@test.com",
            "group_ids": [(4, mobile_group.id), (4, cls.env.ref("base.group_user").id)],
        })
        cls.employee = cls.env["hr.employee"].sudo().create({
            "name": "Split Claim Employee", "company_id": company.id, "user_id": cls.user.id})
        cls.product = cls.env["product.product"].sudo().create({
            "name": "Split Claim Meals", "type": "service", "can_be_expensed": True,
            "standard_price": 0.0})

        expense = cls.env["hr.expense"].create({
            "name": "Split Claim", "employee_id": cls.employee.id, "product_id": cls.product.id,
            "total_amount_currency": 1000.0, "payment_mode": "own_account"})
        wizard = cls.env["hr.expense.split.wizard"].browse(expense.action_split_wizard()["res_id"])
        wizard.action_split_expense()
        cls.halves = cls.env["hr.expense"].search([("split_expense_origin_id", "=", expense.id)])
        cls.halves.action_submit()
        # Odoo 20: approving both together creates the one shared (draft) receipt; posting it is separate.
        cls.halves.action_approve()
        cls.move = cls.halves.account_move_id
        cls.move.action_post()

    def _pay(self, amount):
        """Register *amount* against the shared entry; return the notifications that were queued."""
        with patch.object(
            type(self.env["mobile.push.service"]), "queue_once_to_user"
        ) as send_mock:
            self.env["account.payment.register"].with_context(
                active_model="account.move", active_ids=self.move.ids,
            ).create({"amount": amount, "payment_difference_handling": "open"}).action_create_payments()
        self.env.invalidate_all()
        return [{"type": call.args[1], "body": call.args[5], "data": call.kwargs.get("data") or {}}
                for call in send_mock.call_args_list]

    def test_odoo_posts_both_halves_on_one_entry(self):
        """Precondition (core Odoo): two 500 halves, one 1000 receipt."""
        self.assertEqual(sorted(self.halves.mapped("total_amount")), [500.0, 500.0])
        self.assertEqual(len(self.move), 1)
        self.assertEqual(self.move.amount_total, 1000.0)

    def test_partial_payment_reports_odoos_residual_on_each_half(self):
        self._pay(500.0)
        for half in self.halves.sudo():
            payload = expense_payment_payload(half)
            self.assertEqual(payload["amount_due"], half.amount_residual)
            self.assertEqual(payload["amount_due"], 500.0)
            self.assertEqual(payload["payment_status"], self.move.payment_state)
            self.assertEqual(payload["payment_status"], "partial")
            self.assertFalse(payload["is_fully_paid"])
            self.assertEqual(payload["amount_paid"], max(half.total_amount - half.amount_residual, 0.0))

    def test_unpaid_half_is_capped_at_its_own_total(self):
        """Odoo's residual is the shared 1000 entry's; a 500 half never shows more than 500 due."""
        for half in self.halves.sudo():
            self.assertEqual(half.amount_residual, 1000.0)
            payload = expense_payment_payload(half)
            self.assertEqual(payload["amount_due"], 500.0)
            self.assertEqual(payload["amount_paid"], 0.0)
            self.assertEqual(payload["payment_status"], "not_paid")
        self.assertEqual(self.halves.sudo()._mobile_outstanding_amount(), 1000.0)

    def test_one_half_alone_is_capped_in_the_summary(self):
        self.assertEqual(self.halves[:1].sudo()._mobile_outstanding_amount(), 500.0)

    def test_summary_counts_the_shared_entry_once(self):
        self._pay(500.0)
        self.assertEqual(self.halves.sudo()._mobile_outstanding_amount(), 500.0)

    def test_partial_payment_is_not_announced_as_fully_paid(self):
        sent = self._pay(500.0)
        payment_pushes = [n for n in sent if n["type"] in (EXPENSE_PAID, EXPENSE_PARTIALLY_PAID)]
        self.assertTrue(payment_pushes, "the instalment was not announced")
        for push in payment_pushes:
            self.assertEqual(push["type"], EXPENSE_PARTIALLY_PAID, push["body"])
            self.assertEqual(push["data"]["amount_due"], 500.0)
            self.assertIn("still pending", push["body"])

    def test_full_payment_clears_both_halves(self):
        self._pay(1000.0)
        for half in self.halves.sudo():
            payload = expense_payment_payload(half)
            self.assertEqual(payload["amount_due"], 0.0)
            self.assertEqual(payload["amount_paid"], half.total_amount)
        self.assertEqual(self.halves.sudo()._mobile_outstanding_amount(), 0.0)


@tagged("post_install", "-at_install")
class TestExpenseStatusMatchesOdoo(TransactionCase):
    """The app's status labels are Odoo 20's own, and `in_payment` is not folded into `paid`."""

    def test_status_labels_are_odoos(self):
        from ..controllers.expense import STATUS_MAP, STATUS_DISPLAY
        labels = dict(self.env["hr.expense"]._fields["state"]._description_selection(self.env))
        # `posted` deliberately shows as Approved (Odoo 20 keeps employee-paid claims `approved`).
        for state, label in labels.items():
            if state == "posted":
                continue
            self.assertEqual(STATUS_DISPLAY[STATUS_MAP[state]], label, state)

    def test_in_payment_is_its_own_status(self):
        from ..controllers.expense import STATUS_MAP, STATUS_DISPLAY
        self.assertEqual(STATUS_MAP["in_payment"], "in_payment")
        self.assertEqual(STATUS_DISPLAY["in_payment"], "In Payment")

    def test_payment_status_labels_are_odoos(self):
        from ..controllers.expense import PAYMENT_STATUS_DISPLAY
        labels = dict(self.env["account.move"]._fields["payment_state"]._description_selection(self.env))
        for state, label in PAYMENT_STATUS_DISPLAY.items():
            self.assertEqual(label, labels[state], state)
