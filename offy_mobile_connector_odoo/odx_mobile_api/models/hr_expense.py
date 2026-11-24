import logging

import pytz

from odoo import api, fields, models
from odoo.exceptions import AccessError

from ..notifications import (
    EXPENSE_APPROVED, EXPENSE_PAID, EXPENSE_PARTIALLY_PAID, EXPENSE_REFUSED,
    NOTIFICATION_TITLES,
)

_logger = logging.getLogger(__name__)

EXPENSE_FEATURE_CODE = "expense"


# A push banner shows roughly two lines.
NAME_MAX_CHARS = 45


def _created_date_display(expense):
    """Local calendar day the expense record was created (e.g. "August 15, 2026"), for notifications.
    Runs from write() with no request, so it resolves user tz, employee tz, company tz, UTC via the ORM."""
    if not expense.create_date:
        return None
    employee = expense.employee_id.sudo()
    tz_name = (employee.user_id.tz or employee.tz
               or employee.company_id.resource_calendar_id.tz)
    tz = pytz.timezone(tz_name) if tz_name else pytz.utc
    local = pytz.utc.localize(expense.create_date).astimezone(tz)
    return local.strftime("%B %-d, %Y")


def _created_date_iso(expense):
    """`create_date` as ISO 8601 UTC for the notification `data` payload."""
    return (expense.create_date.strftime("%Y-%m-%dT%H:%M:%SZ")
            if expense.create_date else None)


def _expense_name(expense):
    """The expense name, short enough to leave room for the rest of a
    notification -- see NAME_MAX_CHARS for why."""
    name = (expense.name or "").strip() or "Expense"
    if len(name) > NAME_MAX_CHARS:
        name = name[:NAME_MAX_CHARS].rstrip(" ,.;:-") + "..."
    return name


def _subject(expense):
    """`_expense_name` plus the claim's creation date; used by the payment notification only."""
    name = _expense_name(expense)
    created = _created_date_display(expense)
    return "%s (created %s)" % (name, created) if created else name


def _money(amount, currency):
    """Format an amount the way the mobile expense screens do."""
    symbol = currency.symbol or currency.name or ""
    text = "%.2f" % (amount or 0.0)
    return "%s%s" % (symbol, text) if currency.position == "before" \
        else "%s%s" % (text, symbol)

# Expense states worth telling the employee about.
NOTIFY_BY_STATE = {
    "approved": (EXPENSE_APPROVED, NOTIFICATION_TITLES[EXPENSE_APPROVED], "approved"),
    "posted": (EXPENSE_APPROVED, NOTIFICATION_TITLES[EXPENSE_APPROVED], "approved"),
    "refused": (EXPENSE_REFUSED, NOTIFICATION_TITLES[EXPENSE_REFUSED], "refused"),
    "paid": (EXPENSE_PAID, NOTIFICATION_TITLES[EXPENSE_PAID], "paid"),
}

# `cr.precommit.data` key: expenses whose approval push waits for the end of the transaction.
DEFERRED_APPROVAL_KEY = "odx_mobile_api.deferred_expense_approval_push"
# `cr.precommit.data` key: expenses currently going through Odoo's `_do_approve`.
APPROVING_KEY = "odx_mobile_api.expense_being_approved"

# Types queued by `_notify_mobile_expense_payments`; chosen by amount received, not by state.
NOTIFY_BY_PAYMENT = (EXPENSE_PAID, EXPENSE_PARTIALLY_PAID)

# Fields that change what the mobile home expense card shows.
HOME_RELEVANT_FIELDS = {
    "date",
    "employee_id",
    "total_amount",
    "total_amount_currency",
    "currency_id",
    "quantity",
    "price_unit",
}

SYNC_SECTIONS = ["expense", "activities"]


class HrExpense(models.Model):
    """Keeps the mobile expense card live and pushes approval outcomes.
    Push only on approved/refused/paid; silent sync on create, delete and any card-affecting edit."""

    _name = "hr.expense"
    _inherit = ["hr.expense", "mobile.notify.mixin"]

    def _can_be_autovalidated(self):
        """Block Odoo's no-approver auto-validation when `mobile_block_self_approval` is in context.
        Only the mobile submit path sets it; the 'employee is own approver' branch is left untouched."""
        if self.env.context.get("mobile_block_self_approval"):
            return False
        return super()._can_be_autovalidated()

    @api.model_create_multi
    def create(self, vals_list):
        expenses = super().create(vals_list)
        # A new expense changes the home card counts, so sync it straight away.
        expenses._sync_mobile_home_for_employees(
            expenses.mapped("employee_id"), SYNC_SECTIONS,
            reason="expense_created",
        )
        return expenses

    def write(self, vals):
        # Captured before the write: a reassigned expense must refresh the former employee too.
        employees_before = self.mapped("employee_id")

        res = super().write(vals)

        if set(vals) & HOME_RELEVANT_FIELDS:
            self._sync_mobile_home_for_employees(
                employees_before | self.mapped("employee_id"),
                SYNC_SECTIONS,
                reason="expense_updated",
            )
        return res

    def _compute_state(self):
        """Recompute `state`, then notify on every real transition.
        Stored compute never appears in write() vals, so hook here; old value read by SQL as the cache is dirty."""
        real_ids = [rid for rid in self.ids if isinstance(rid, int)]
        before = {}
        if real_ids:
            self.env.cr.execute(
                "SELECT id, state FROM hr_expense WHERE id IN %s",
                (tuple(real_ids),),
            )
            before = dict(self.env.cr.fetchall())

        super()._compute_state()

        changed = self.browse()
        for expense in self:
            if expense.id not in before:
                continue  # new/unsaved record -- nothing to compare against
            if expense.state == before[expense.id]:
                continue  # recompute ran, but nothing actually changed
            expense._notify_mobile_expense_state()
            changed |= expense

        if changed:
            changed._sync_mobile_home_for_employees(
                changed.mapped("employee_id"), SYNC_SECTIONS,
                reason="expense_state_changed",
            )

    def unlink(self):
        # Capture before the rows go; afterwards there is no employee left to refresh.
        employees = self.mapped("employee_id")
        res = super().unlink()
        self._sync_mobile_home_for_employees(
            employees, SYNC_SECTIONS, reason="expense_deleted")
        return res

    def _mobile_payment_allocations(self):
        """Reimbursements on this expense, oldest first: [(payment, amount, date, amount_currency)].
        Read from partial reconciles since a payment may be split; amount is company currency. No sudo."""
        self.ensure_one()
        move = self.account_move_id
        if not move or not move.line_ids:
            return []

        lines = move.line_ids
        partials = self.env["account.partial.reconcile"].search([
            "|",
            ("debit_move_id", "in", lines.ids),
            ("credit_move_id", "in", lines.ids),
        ])

        # Several partials can belong to one payment (one per matched line); sum them per payment.
        by_payment = {}
        for partial in partials:
            is_debit_side = partial.debit_move_id in lines
            counterpart = (partial.credit_move_id if is_debit_side
                           else partial.debit_move_id)
            payment = counterpart.move_id.origin_payment_id
            if not payment:
                continue  # matched against something that is not a payment
            # The bill line sits on `is_debit_side`; the amount to take is on the opposite side.
            side_currency_amount = (partial.credit_amount_currency if is_debit_side
                                    else partial.debit_amount_currency)
            entry = by_payment.setdefault(
                payment.id, {"amount": 0.0, "amount_currency": 0.0, "date": None})
            entry["amount"] += partial.amount or 0.0
            entry["amount_currency"] += side_currency_amount or 0.0
            partial_date = partial.max_date or counterpart.date
            entry["date"] = (partial_date if entry["date"] is None
                             else min(entry["date"], partial_date))

        payments = self.env["account.payment"].browse(by_payment)
        allocations = [
            (payment, by_payment[payment.id]["amount"],
             by_payment[payment.id]["date"],
             by_payment[payment.id]["amount_currency"])
            for payment in payments
        ]
        # Chronological: the callers' running total is only meaningful in payment order.
        allocations.sort(key=lambda a: (a[2] or fields.Date.today(), a[0].id))
        return allocations

    def _mobile_amount_due(self):
        """Amount still owed on this expense: Odoo's `amount_residual`, capped at the expense's own total.
        Expenses posted together share one journal entry, whose residual can exceed a single expense."""
        self.ensure_one()
        if self.state in ("draft", "refused"):
            return 0.0
        total = self.total_amount or 0.0
        if not self.account_move_id:
            return total
        return min(max(self.amount_residual or 0.0, 0.0), total)

    def _mobile_outstanding_amount(self):
        """Total still owed across these expenses; a shared journal entry counts once.
        Per entry: its residual, capped at the totals of the expenses in this set that it carries."""
        total = 0.0
        by_move = {}
        for expense in self:
            move = expense.account_move_id
            if move and expense.state not in ("draft", "refused"):
                by_move.setdefault(move, self.browse())
                by_move[move] |= expense
            else:
                total += expense._mobile_amount_due()
        for move, expenses in by_move.items():
            residual = max(move.amount_residual or 0.0, 0.0)
            total += min(residual, sum(expenses.mapped("total_amount")))
        return total

    def _notify_mobile_expense_payments(self):
        """Announce each reimbursement instalment once per payment, from `account.partial.reconcile.create`.
        Deduplicated by an expense/payment `dedup_key`, since recomputes may call this repeatedly."""
        for expense in self:
            try:
                allocations = expense._mobile_payment_allocations()
            except AccessError:
                continue  # not our business to widen the reader's rights
            if not allocations:
                continue

            company_currency = expense.company_currency_id or expense.currency_id
            move = expense.account_move_id
            # Odoo's own figures for the journal entry, which several split expenses may share.
            total = abs(move.amount_total_signed)
            odoo_residual = max(abs(move.amount_residual_signed), 0.0)
            running = 0.0
            for index, (payment, amount, _date, _amount_currency) in enumerate(allocations):
                running += amount
                # The latest instalment reports Odoo's residual as is; earlier ones are reconstructed.
                remaining = (odoo_residual if index == len(allocations) - 1
                             else max(total - running, 0.0))
                fully_paid = company_currency.is_zero(remaining)

                if fully_paid and len(allocations) == 1:
                    # Single payment: instalment and total are the same figure, so quote it once.
                    notification_type = EXPENSE_PAID
                    body = "%s received. Your expense is now fully paid." % (
                        _money(amount, company_currency),
                    )
                elif fully_paid:
                    notification_type = EXPENSE_PAID
                    body = "%s received. Your expense of %s is now fully paid." % (
                        _money(amount, company_currency),
                        _money(total, company_currency),
                    )
                else:
                    notification_type = EXPENSE_PARTIALLY_PAID
                    # "of <total>" anchors the remainder so it is not read as the instalment.
                    body = "%s received. %s of %s still pending." % (
                        _money(amount, company_currency),
                        _money(remaining, company_currency),
                        _money(total, company_currency),
                    )

                expense._queue_mobile_notification(
                    expense.employee_id,
                    EXPENSE_FEATURE_CODE,
                    notification_type,
                    NOTIFICATION_TITLES[notification_type],
                    "%s: %s" % (_subject(expense), body),
                    data={
                        "expense_id": expense.id,
                        "payment_id": payment.id,
                        "amount": amount,
                        "amount_display": _money(amount, company_currency),
                        "amount_paid": running,
                        "amount_paid_display": _money(running, company_currency),
                        "amount_due": remaining,
                        "amount_due_display": _money(remaining, company_currency),
                        "total_amount": total,
                        "total_amount_display": _money(total, company_currency),
                        "currency": company_currency.name,
                        "is_fully_paid": fully_paid,
                        "state": expense._mobile_v19_state(),
                        "created_date": _created_date_iso(expense),
                        "action": "open_expense_detail",
                    },
                    dedup_key="expense:%s:payment:%s" % (expense.id, payment.id),
                )

            # A reimbursement changes what /expense/summary reports as outstanding.
            expense._sync_mobile_home_for_employees(
                expense.employee_id, SYNC_SECTIONS, reason="expense_paid")

    def _mobile_v19_state(self):
        """`state` in the Odoo 19 vocabulary used in notification payloads.
        Odoo 20 keeps an employee-paid expense `approved` while its journal entry is posted and
        unpaid; Odoo 19 called that `posted`. Payload value only: no extra push is sent."""
        self.ensure_one()
        if self.state != "approved" or self.payment_mode == "company_account":
            return self.state
        try:
            move_posted = self.account_move_id.state == "posted"
        except AccessError:
            return self.state
        return "posted" if move_posted else self.state

    def _do_approve(self):
        """Odoo 20 approval: writes `approval_state`, THEN creates the draft entry. Mark these
        expenses so their approval push waits for the end of the transaction (see below)."""
        self.env.cr.precommit.data.setdefault(APPROVING_KEY, set()).update(self.ids)
        return super()._do_approve()

    def _mobile_entry_may_still_post(self):
        """True while an employee-paid approval may still get a posted entry in this transaction:
        it is being approved through `_do_approve`, or its entry is a draft. v19 announced
        approve + post in one transaction as ONE push carrying state `posted`."""
        self.ensure_one()
        if self.payment_mode == "company_account":
            return False
        if self.id in self.env.cr.precommit.data.get(APPROVING_KEY, ()):
            return True
        try:
            return self.account_move_id.state == "draft"
        except AccessError:
            return False

    def _mobile_defer_approval_push(self):
        """Queue the approval push at the end of the transaction instead of now (see
        `_mobile_flush_deferred_approval_pushes`). Nothing is sent before commit either way."""
        pending = self.env.cr.precommit.data.setdefault(DEFERRED_APPROVAL_KEY, set())
        if not pending:
            self.env.cr.precommit.add(self.browse()._mobile_flush_deferred_approval_pushes)
        pending.update(self.ids)

    def _mobile_flush_deferred_approval_pushes(self):
        ids = self.env.cr.precommit.data.pop(DEFERRED_APPROVAL_KEY, set())
        self.env.cr.precommit.data.pop(APPROVING_KEY, None)
        expenses = self.browse(ids).exists().filtered(lambda e: e.state == "approved")
        expenses._notify_mobile_expense_state(deferred=True)

    def _notify_mobile_expense_state(self, deferred=False):
        for expense in self:
            entry = NOTIFY_BY_STATE.get(expense.state)
            if not entry:
                continue
            # Odoo 20 approval creates a DRAFT entry and posting it later does not change `state`.
            # v19 sent one push with state `posted` when both happened together, so wait for the
            # end of the transaction and read the entry then (`_mobile_v19_state`).
            if (not deferred and expense.state == "approved"
                    and expense._mobile_entry_may_still_post()):
                expense._mobile_defer_approval_push()
                continue
            if expense.state == "paid":
                # Reimbursed expenses are announced per payment instead.
                try:
                    if expense._mobile_payment_allocations():
                        continue
                except AccessError:
                    continue
            notification_type, title, verb = entry
            company_currency = expense.company_currency_id or expense.currency_id
            amount_display = _money(expense.total_amount, company_currency)
            created = _created_date_display(expense)
            if created:
                body = "%s: Your expense of %s created at %s has been %s." % (
                    _expense_name(expense), amount_display, created, verb)
            else:
                body = "%s: Your expense of %s has been %s." % (
                    _expense_name(expense), amount_display, verb)
            expense._queue_mobile_notification(
                expense.employee_id,
                EXPENSE_FEATURE_CODE,
                notification_type,
                title,
                body,
                data={
                    "expense_id": expense.id,
                    "state": expense._mobile_v19_state(),
                    "created_date": _created_date_iso(expense),
                    "amount": expense.total_amount,
                    "amount_display": amount_display,
                    "currency": company_currency.name,
                    "action": "open_expense_detail",
                },
                # A decision can be re-made; write_date keeps each event distinct.
                dedup_key="expense:%s:%s:%s" % (
                    expense.id, expense._mobile_v19_state(), expense.write_date or ""),
            )
