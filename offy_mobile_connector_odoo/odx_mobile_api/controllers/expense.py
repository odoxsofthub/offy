import base64
import json
import logging
import re
from datetime import timedelta

from odoo import fields
from odoo.fields import Domain
from odoo.exceptions import AccessError, UserError, ValidationError
from odoo.http import request

from . import main
from .main import API_KEY_SCOPE
from .uploads import validate_upload
from ..filter_sources import ExpenseFilterSource, range_label, timeline_label

_logger = logging.getLogger(__name__)

# hr.expense.state (computed) -> stable mobile status.
STATUS_MAP = {
    "draft": "draft",
    "submitted": "pending",
    "approved": "approved",
    "posted": "approved",
    "in_payment": "paid",
    "paid": "paid",
    "refused": "refused",
}
STATUS_DISPLAY = {
    "draft": "Draft",
    "pending": "Pending",
    "approved": "Approved",
    "refused": "Refused",
    "paid": "Paid",
}

# Odoo's `account.move.payment_state`, mapped to the wording an employee expects.
PAYMENT_STATUS_DISPLAY = {
    "not_paid": "Not Paid",
    "in_payment": "Payment In Progress",
    "partial": "Partially Paid",
    "paid": "Fully Paid",
    "reversed": "Reversed",
    "blocked": "Blocked",
}
# States in which no reimbursement is ever coming, so nothing is "due".
NEVER_PAID_STATES = ("draft", "refused")
# An expense with no journal entry yet has no payment state; it is simply not paid.
PAYMENT_STATUS_NONE = "not_paid"


# States in which an "own_account" expense can still owe the employee money.
PENDING_REIMBURSEMENT_STATES = (
    "submitted", "approved", "posted", "in_payment", "paid",
)

DEFAULT_APPROVAL_DAYS = 2
MIN_SAMPLES_FOR_AVERAGE = 3
APPROVAL_SAMPLE_LIMIT = 20

RECENT_EXPENSE_LIMIT = 3
MAX_PAGE_LIMIT = 50
DEFAULT_PAGE_LIMIT = 20

# Who may still have a claim auto-approved when the employee has NO approver.
SELF_APPROVE_GROUP = "base.group_system"

MAX_RECEIPTS_PER_EXPENSE = 5
MAX_RECEIPT_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB
# multipart/form-data field names the mobile client may use for receipt files.
RECEIPT_FIELD_NAME = "file"
RECEIPT_FIELD_NAMES = (
    RECEIPT_FIELD_NAME,
    "receipt",
    "receipt_images",
    "receipt_images[]",
    # Alias kept for earlier mobile builds.
    "files",
    "files[]",
)

# Best-effort presentation icon guessed from the category/product name.
_ICON_KEYWORDS = (
    # Order matters: the first matching bucket wins, so specific buckets precede generic ones.
    ("fuel", ("fuel", "petrol", "diesel", "gasoline", "gas station",
              "ev charging", "charging")),
    ("parking", ("parking", "valet")),
    ("toll", ("toll", "tolls", "congestion charge")),
    ("plane", ("flight", "flights", "airfare", "airline", "air ticket",
               "air travel", "travel", "trip", "tour", "baggage")),
    ("train", ("train", "rail", "railway", "metro", "subway", "tram")),
    ("bus", ("bus", "shuttle")),
    # `mileage` belongs with `car`, not `plane`: mileage reimbursement is for driving.
    ("car", ("taxi", "cab", "uber", "lyft", "ride", "rideshare", "car",
             "vehicle", "mileage", "transport", "commute", "driving")),
    ("hotel", ("hotel", "accommodation", "lodging", "motel", "hostel",
               "airbnb", "stay")),
    ("passport", ("visa", "passport", "immigration", "work permit")),
    ("coffee", ("coffee", "cafe", "tea", "snack", "snacks", "beverage",
                "beverages", "refreshment", "refreshments")),
    ("utensils", ("meal", "meals", "food", "lunch", "dinner", "breakfast",
                  "restaurant", "catering", "per diem", "groceries")),
    ("entertainment", ("entertainment", "event", "events", "team building",
                       "hospitality", "social event")),
    ("gift", ("gift", "gifts", "present", "award", "reward", "incentive")),
    ("health", ("medical", "health", "healthcare", "doctor", "pharmacy",
                "hospital", "clinic", "dental", "medicine")),
    ("education", ("training", "course", "courses", "seminar", "conference",
                   "workshop", "certification", "tuition", "exam", "book",
                   "books", "education", "learning")),
    ("software", ("software", "saas", "license", "licence", "subscription",
                  "cloud", "hosting", "domain")),
    ("laptop", ("laptop", "computer", "hardware", "equipment", "monitor",
                "device", "peripheral")),
    ("phone", ("phone", "mobile", "telephone", "sim", "airtime", "roaming",
               "communication")),
    ("wifi", ("internet", "wifi", "broadband", "data plan")),
    ("printer", ("printing", "print", "photocopy", "copier", "toner",
                 "cartridge")),
    ("postage", ("postage", "courier", "shipping", "freight", "delivery",
                 "parcel", "mail")),
    # `building` precedes `box`: "Office Rent" is rent, not office supplies.
    ("building", ("rent", "lease", "utilities", "electricity", "water",
                  "gas bill", "facility", "cleaning", "maintenance")),
    ("box", ("supplies", "stationery", "consumable", "consumables", "office")),
    ("marketing", ("marketing", "advertising", "advert", "adverts",
                   "promotion", "campaign", "sponsorship", "branding",
                   "media")),
    ("legal", ("legal", "lawyer", "attorney", "notary", "compliance",
               "audit", "consulting", "professional fee")),
    ("bank", ("bank", "bank fee", "bank charge", "transaction fee", "forex",
              "exchange rate", "interest")),
    ("insurance", ("insurance", "premium", "policy")),
    ("tax", ("tax", "taxes", "vat", "gst", "duty", "customs", "levy")),
    ("membership", ("membership", "association", "dues", "union dues",
                    "club")),
)
DEFAULT_ICON = "receipt"

# Every slug this endpoint can emit, default included.
EXPENSE_ICONS = tuple(icon for icon, _keywords in _ICON_KEYWORDS) + (DEFAULT_ICON,)

# Compiled once at import.
_ICON_PATTERNS = tuple(
    (icon, re.compile(r"\b(?:%s)\b" % "|".join(re.escape(k) for k in keywords)))
    for icon, keywords in _ICON_KEYWORDS
)


def _iso_date(d):
    return d.isoformat() if d else None


def _category_icon(name):
    """Classify an expense category name into an icon slug.
    Presentational only; an unrecognised name falls back to `receipt`."""
    lowered = (name or "").lower()
    for icon, pattern in _ICON_PATTERNS:
        if pattern.search(lowered):
            return icon
    return DEFAULT_ICON


def _format_amount(amount, currency):
    symbol = currency.symbol or currency.name or ""
    text = "%.2f" % (amount or 0.0)
    if currency.position == "before":
        return "%s%s" % (symbol, text)
    return "%s%s" % (text, symbol)


def _search_amount(term):
    """Return *term* as a money amount, or None when the whole term is not a number.
    Tolerates thousands separators and a currency symbol, as rendered on the row."""
    cleaned = term.replace(",", "").strip().strip("₹$€£¥ ").strip()
    if not cleaned:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def _search_domain(term):
    """Domain matching *term* against an expense row's title, category and amount.
    List form so it ANDs with the caller's domain and never widens employee scoping."""
    parts = [
        Domain("name", "ilike", term),
        Domain("product_id.name", "ilike", term),
    ]
    amount = _search_amount(term)
    if amount is not None:
        # Rounded window rather than `=`: `total_amount` is a float column (binary representation).
        parts.append(Domain("total_amount", ">=", amount - 0.005)
                     & Domain("total_amount", "<=", amount + 0.005))
    return list(Domain.OR(parts))


def _business_days_between(start_date, end_date):
    """Count weekdays strictly between two dates (end exclusive of start)."""
    if not start_date or not end_date or end_date <= start_date:
        return 0
    days = 0
    current = start_date
    # Expense approvals are short-lived, so this loop is capped at 3650 iterations.
    max_iterations = 3650
    while current < end_date and max_iterations:
        current += timedelta(days=1)
        max_iterations -= 1
        if current.weekday() < 5:
            days += 1
    return days


def expense_amount_due(expense):
    """Amount still owed to the employee on one expense.
    Delegates to `hr.expense._mobile_amount_due` so the notification and summary agree."""
    return expense._mobile_amount_due()


def expense_payment_payload(expense):
    """Paid and outstanding amounts on an expense, in company currency.
    Kept out of `expense_payload` because it costs a payment query per expense."""
    move = expense.account_move_id
    company_currency = expense.company_currency_id or expense.currency_id
    total = expense.total_amount or 0.0

    if expense.state in NEVER_PAID_STATES:
        # A refused or draft claim will never be reimbursed.
        status = PAYMENT_STATUS_NONE
        paid = due = 0.0
        allocations = []
    elif not move:
        # Approved but not yet posted to accounting: owed, but nothing paid and no journal entry.
        status = PAYMENT_STATUS_NONE
        paid, due = 0.0, total
        allocations = []
    else:
        status = move.payment_state or PAYMENT_STATUS_NONE
        due = expense.amount_residual or 0.0
        # Use `_mobile_payment_allocations()`, not `move._get_reconciled_payments()`, for per-expense amounts.
        allocations = expense._mobile_payment_allocations()
        # `paid` is still derived from the residual, not summed from the allocations.
        paid = max(total - due, 0.0)

        # ...unless the journal entry does not represent this expense's amount.
        if move.currency_id == company_currency and \
                company_currency.compare_amounts(move.amount_total, total) != 0:
            reconciled = sum(
                amount for _payment, amount, _date, _amount_currency
                in allocations)
            paid = min(max(reconciled, 0.0), total)
            due = max(total - paid, 0.0)
            status = ("paid" if company_currency.is_zero(due)
                      else "partial" if paid > 0
                      else PAYMENT_STATUS_NONE)
            _logger.warning(
                "Expense %s totals %s but its journal entry %s totals %s; "
                "reporting payment from reconciled payments (%s) instead of "
                "the entry's residual. The entry likely predates an edit to "
                "the expense amount.",
                expense.id, total, move.id, move.amount_total, paid)

    return {
        "total_amount": total,
        "total_amount_display": _format_amount(total, company_currency),
        "amount_paid": paid,
        "amount_paid_display": _format_amount(paid, company_currency),
        "amount_due": due,
        "amount_due_display": _format_amount(due, company_currency),
        "payment_currency": company_currency.name,
        # Distinct from `status`: see PAYMENT_STATUS_DISPLAY.
        "payment_status": status,
        "payment_status_display": PAYMENT_STATUS_DISPLAY.get(
            status, status.replace("_", " ").title()),
        "is_fully_paid": status == "paid",
        "is_partially_paid": status == "partial",
        # `amount` is the ALLOCATED portion of this payment against THIS expense, not the payment total.
        "payments": [{
            "id": payment.id,
            "amount": amount_currency,
            "amount_display": _format_amount(
                amount_currency, payment.currency_id or company_currency),
            "currency": (payment.currency_id or company_currency).name,
            "date": _iso_date(date),
            "state": payment.state,
            "memo": payment.memo or None,
        } for payment, _amount, date, amount_currency in allocations],
    }


def expense_is_own(expense, user):
    """True when *user* is the employee the claim belongs to."""
    return bool(expense.employee_id.user_id and
                expense.employee_id.user_id.id == user.id)


def expense_can_withdraw(expense, user):
    """Whether *user* may pull their own `submitted` claim back to draft.
    Defers entirely to Odoo's `can_reset`."""
    return expense.state == "submitted" and bool(expense.can_reset)


def expense_can_edit(expense, user):
    """Whether `PATCH /expense` would accept this claim from *user* (draft or submitted).
    Same expression `expense_update` enforces, so `is_editable` cannot drift."""
    if not expense_is_own(expense, user):
        return False
    return expense.state == "draft" or expense_can_withdraw(expense, user)


def expense_can_delete(expense, user):
    """Whether `DELETE /expenses/<id>` would accept this claim from *user*.
    Same rule as editing: a `submitted` claim is reset to draft first."""
    if not expense_is_own(expense, user):
        return False
    return expense.state == "draft" or expense_can_withdraw(expense, user)


def expense_payload(expense, currency):
    """One expense as the mobile app renders it in a list.
    Shared by the expense lists and `/log-note/messages` so the shape stays identical."""
    state = STATUS_MAP.get(expense.state, expense.state)
    # Use `total_amount` (company currency), NOT `total_amount_currency`: callers show the company symbol.
    amount = expense.total_amount
    return {
        "id": expense.id,
        "title": expense.name,
        "category": expense.product_id.name or None,
        "date": _iso_date(expense.date),
        "amount": amount,
        "amount_display": "(%s)" % _format_amount(amount, currency),
        "currency": currency.name,
        "status": state,
        "status_display": STATUS_DISPLAY.get(state, state.title()),
        "icon": _category_icon(expense.product_id.name),
        "has_receipt": bool(expense.attachment_ids),
        # Whether THIS caller may edit / delete THIS claim, decided server-side so the app never guesses.
        "is_editable": expense_can_edit(expense, request.env.user),
        "is_deletable": expense_can_delete(expense, request.env.user),
    }


class MobileApiExpense(main.MobileApiAuth):
    """Expense screens data: dashboard summary, categories, list, create."""

    def _authenticate_expense(self, need_write=False):
        """Shared auth, eligibility, expense feature and employee resolution.
        Returns (user, error_response); error_response is None on success."""
        token = self._bearer_token()
        if not token:
            return None, self._json(success=False, code="missing_access_token",
                                    message="Missing access token", status=401)
        uid = request.env["res.users.apikeys"].sudo()._check_credentials(
            scope=API_KEY_SCOPE, key=token
        )
        if not uid:
            return None, self._json(success=False, code="invalid_access_token",
                                    message="Invalid access token", status=401)

        request.update_env(user=uid)
        user = request.env.user
        if not user.active:
            return None, self._json(success=False, code="user_inactive",
                                    message="User is inactive", status=403)
        ok, message = self._check_mobile_access(user)
        if not ok:
            return None, self._json(success=False, code="mobile_access_denied",
                                    message=message, status=403)

        request.update_context(
            allowed_company_ids=self._get_company_context(uid))
        # Re-bound after the switch: res.users.employee_id depends on the company context.
        user = request.env.user

        if not self._mobile_feature_allowed(user, "expense"):
            return None, self._json(success=False, code="expense_access_denied",
                                    message="You do not have permission to %s expenses."
                                            % ("submit" if need_write else "view"),
                                    status=403)

        if not user.employee_id:
            return None, self._json(success=False, code="employee_not_found",
                                    message="No employee profile is linked to this "
                                            "mobile user.", status=404)
        return user, None

    def _expense_payload(self, expense, currency):
        """Thin wrapper kept so existing call sites read unchanged."""
        return expense_payload(expense, currency)

    def _average_approval_time(self, employee):
        """Average business days between submission and approval, per employee.
        Falls back to a default below MIN_SAMPLES_FOR_AVERAGE samples."""
        expenses = request.env["hr.expense"].search([
            ("employee_id", "=", employee.id),
            ("approval_date", "!=", False),
        ], order="approval_date desc", limit=APPROVAL_SAMPLE_LIMIT)

        samples = []
        for expense in expenses:
            start = fields.Datetime.context_timestamp(expense, expense.create_date).date()
            end = fields.Datetime.context_timestamp(expense, expense.approval_date).date()
            days = _business_days_between(start, end)
            if days > 0:
                samples.append(days)

        if len(samples) < MIN_SAMPLES_FOR_AVERAGE:
            return {
                "value": DEFAULT_APPROVAL_DAYS,
                "unit": "business_days",
                "display": "%d business days" % DEFAULT_APPROVAL_DAYS,
                "source": "default",
            }

        average = round(sum(samples) / len(samples))
        average = max(average, 1)
        return {
            "value": average,
            "unit": "business_days",
            "display": "%d business day%s" % (average, "" if average == 1 else "s"),
            "source": "calculated",
        }

    @main.http.route("/api/mobile/v1/expense/summary", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def expense_summary(self, **kwargs):
        user, err = self._authenticate_expense()
        if err:
            return err
        employee = user.employee_id
        currency = request.env.company.currency_id

        try:
            pending_domain = [
                ("employee_id", "=", employee.id),
                ("payment_mode", "=", "own_account"),
                ("state", "in", PENDING_REIMBURSEMENT_STATES),
            ]
            pending_expenses = request.env["hr.expense"].search(pending_domain)
            # sudo(): the outstanding figure comes from `account.move`, which a mobile user cannot read.
            outstanding = {
                expense.id: expense_amount_due(expense)
                for expense in pending_expenses.sudo()
            }
            pending_amount = sum(outstanding.values())
            # A fully settled expense still matches the state domain, so filter on the amount still due.
            pending_expenses = pending_expenses.filtered(
                lambda e: outstanding.get(e.id, 0.0) > 0.0)

            recent = request.env["hr.expense"].search(
                [("employee_id", "=", employee.id)],
                order="date desc, id desc", limit=RECENT_EXPENSE_LIMIT,
            )
            average_approval_time = self._average_approval_time(employee)
            recent_payload = [self._expense_payload(e, currency) for e in recent]
        except AccessError:
            # e.g. a mobile user without base.group_user.
            return self._json(success=False, code="expense_access_denied",
                              message="You do not have permission to view expenses.",
                              status=403)

        return self._json(success=True, message="Expense summary fetched successfully", data={
            "pending_reimbursement_amount": pending_amount,
            "pending_reimbursement_display": _format_amount(pending_amount, currency),
            "pending_count": len(pending_expenses),
            "average_approval_time": average_approval_time,
            "recent_expenses": recent_payload,
        })

    @main.http.route("/api/mobile/v1/expense/categories", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def expense_categories(self, **kwargs):
        user, err = self._authenticate_expense()
        if err:
            return err

        try:
            products = request.env["product.product"].search(
                [("can_be_expensed", "=", True)], order="name asc"
            )
            data = [{
                "id": product.id,
                "name": product.name,
                "icon": _category_icon(product.name),
                "sequence": (index + 1) * 10,
            } for index, product in enumerate(products)]
        except AccessError:
            return self._json(success=False, code="expense_access_denied",
                              message="You do not have permission to view expense "
                                      "categories.", status=403)
        return self._json(success=True, message="Expense categories fetched successfully",
                          data=data)

    @main.http.route("/api/mobile/v1/expense", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def expense_list(self, **kwargs):
        user, err = self._authenticate_expense()
        if err:
            return err
        employee = user.employee_id
        currency = request.env.company.currency_id

        try:
            page = int(kwargs.get("page", 1))
            limit = int(kwargs.get("limit", DEFAULT_PAGE_LIMIT))
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_pagination",
                              message="page and limit must be integers.", status=400)
        if page < 1 or limit < 1:
            return self._json(success=False, code="invalid_pagination",
                              message="page and limit must be >= 1.", status=400)
        limit = min(limit, MAX_PAGE_LIMIT)

        domain = [("employee_id", "=", employee.id)]

        status = (kwargs.get("status") or "").strip().lower()
        if status:
            matching_states = [s for s, mapped in STATUS_MAP.items() if mapped == status]
            if not matching_states:
                return self._json(success=False, code="invalid_status",
                                  message="Unknown status filter: %s" % status, status=400)
            domain.append(("state", "in", matching_states))

        date_from = (kwargs.get("date_from") or "").strip()
        if date_from:
            parsed = main.parse_date(date_from)
            if not parsed:
                return self._json(success=False, code="invalid_date",
                                  message="date_from must be a valid date (YYYY-MM-DD).",
                                  status=400)
            domain.append(("date", ">=", parsed))

        date_to = (kwargs.get("date_to") or "").strip()
        if date_to:
            parsed = main.parse_date(date_to)
            if not parsed:
                return self._json(success=False, code="invalid_date",
                                  message="date_to must be a valid date (YYYY-MM-DD).",
                                  status=400)
            domain.append(("date", "<=", parsed))

        category_id = kwargs.get("category_id")
        if category_id:
            try:
                domain.append(("product_id", "=", int(category_id)))
            except (TypeError, ValueError):
                return self._json(success=False, code="invalid_category",
                                  message="category_id must be an integer.", status=400)

        search = (kwargs.get("search") or "").strip()
        if search:
            domain += _search_domain(search)

        # Stored per-user filters apply implicitly (not route params) and AND with the explicit query params.
        source = ExpenseFilterSource(user)
        filter_state = request.env["mobile.list.filter"].get_state(
            user, source.code)
        domain += source.domain_from_state(filter_state)

        try:
            expense_model = request.env["hr.expense"]
            total = expense_model.search_count(domain)
            expenses = expense_model.search(
                domain, order="date desc, id desc",
                limit=limit, offset=(page - 1) * limit,
            )
            items = [self._expense_payload(e, currency) for e in expenses]
        except AccessError:
            return self._json(success=False, code="expense_access_denied",
                              message="You do not have permission to view expenses.",
                              status=403)

        return self._json(success=True, message="Expenses fetched successfully", data={
            # `groups` is the ONLY list of expenses, built from the already-paginated page.
            "groups": self._timeline_groups(
                expenses, items, source, filter_state, domain, currency),
            "pagination": {
                "page": page,
                "limit": limit,
                "total": total,
                "has_next": page * limit < total,
                "has_previous": page > 1,
            },
            "filters": {"active": source.active_payload(filter_state)},
        })

    @staticmethod
    def _timeline_totals(domain, group_by_month):
        """Total spend per timeline over the whole filtered set, not just the page.
        Keeps a month's header total stable across pages; one aggregate query, company currency."""
        if group_by_month:
            rows = request.env["hr.expense"]._read_group(
                domain, ["date:month"], ["total_amount:sum"])
            return {(value.year, value.month): total
                    for value, total in rows if value}
        rows = request.env["hr.expense"]._read_group(
            domain, [], ["total_amount:sum"])
        return {None: (rows[0][0] if rows else 0.0) or 0.0}

    @staticmethod
    def _timeline_groups(expenses, items, source, filter_state, domain, currency):
        """Bucket the page into `[{"timeline": .., "expenses": [..]}]` by month.
        Grouping runs after pagination; a custom date range collapses into one group."""
        if not expenses:
            return []

        bounds = source.range_bounds(filter_state)
        if bounds:
            total = MobileApiExpense._timeline_totals(domain, False)[None]
            return [{
                "timeline": range_label(*bounds),
                "total_amount": total,
                "total_amount_display": _format_amount(total, currency),
                "currency": currency.name,
                "expenses": list(items),
            }]

        totals = MobileApiExpense._timeline_totals(domain, True)
        groups = []
        current_key = None
        for expense, payload in zip(expenses, items):
            value = expense.date
            key = (value.year, value.month) if value else None
            if key != current_key:
                total = totals.get(key, 0.0) or 0.0
                groups.append({
                    "timeline": timeline_label(value) if value else "Undated",
                    "total_amount": total,
                    "total_amount_display": _format_amount(total, currency),
                    "currency": currency.name,
                    "expenses": [],
                })
                current_key = key
            groups[-1]["expenses"].append(payload)
        return groups

    def _validate_receipt_file(self, file_storage, content):
        """Validate one uploaded receipt; return ``(mimetype, None)`` or ``(None, message)``.
        The mimetype comes from `uploads.validate_upload`, never the client-set header."""
        if not file_storage or not (file_storage.filename or "").strip():
            return None, "Each receipt image must include a filename."
        return validate_upload(file_storage.filename, content)

    def _expense_create_payload(self, kwargs):
        """Merge JSON/query/form fields for the create endpoint."""
        payload = {}
        payload.update(self._payload())
        payload.update(kwargs or {})
        payload.update(request.httprequest.form.to_dict(flat=True))
        return payload

    def _expense_receipt_files(self):
        files = []
        for field_name in RECEIPT_FIELD_NAMES:
            files.extend(request.httprequest.files.getlist(field_name))
        return files

    def _validate_expense_fields(self, payload):
        """Validate the fields common to create and update.
        Returns ``(values, None)`` ready for create()/write(), or ``(None, error_response)``."""
        raw_amount = payload.get("amount")
        if isinstance(raw_amount, str):
            raw_amount = raw_amount.strip().replace(",", "")
        try:
            amount = float(raw_amount)
        except (TypeError, ValueError):
            return None, self._json(success=False, code="invalid_amount",
                                    message="Expense amount must be a number.", status=400)
        if amount <= 0:
            return None, self._json(success=False, code="invalid_amount",
                                    message="Expense amount must be greater than zero.",
                                    status=400)

        raw_category_id = payload.get("category_id")
        if isinstance(raw_category_id, str):
            raw_category_id = raw_category_id.strip()
        try:
            category_id = int(raw_category_id)
        except (TypeError, ValueError):
            return None, self._json(success=False, code="invalid_category",
                                    message="category_id is required and must be an integer.",
                                    status=400)
        product = request.env["product.product"].search([
            ("id", "=", category_id), ("can_be_expensed", "=", True),
        ], limit=1)
        if not product:
            return None, self._json(success=False, code="invalid_category",
                                    message="Selected category is not available for expenses.",
                                    status=400)

        raw_expense_date = payload.get("expense_date")
        if isinstance(raw_expense_date, str):
            raw_expense_date = raw_expense_date.strip()
        expense_date = main.parse_date(raw_expense_date)
        if not expense_date:
            return None, self._json(success=False, code="invalid_date",
                                    message="expense_date is required and must be a valid date "
                                            "(YYYY-MM-DD).", status=400)

        description = (payload.get("description") or "").strip()
        return {
            "title": description or product.name,
            "product": product,
            "amount": amount,
            "expense_date": expense_date,
            "description": description,
        }, None

    def _validate_expense_receipts(self):
        """Validate uploaded receipt files before they become attachments.
        Returns ``([(filename, mimetype, raw_bytes)], None)`` or ``(None, error_response)``."""
        receipt_files = self._expense_receipt_files()
        if len(receipt_files) > MAX_RECEIPTS_PER_EXPENSE:
            return None, self._json(success=False, code="too_many_receipts",
                                    message="A maximum of %d receipt images is allowed."
                                            % MAX_RECEIPTS_PER_EXPENSE, status=400)

        receipts = []
        for file_storage in receipt_files:
            if not (file_storage.filename or "").strip():
                return None, self._json(success=False, code="invalid_receipt",
                                        message="Each receipt image must include a filename.",
                                        status=400)
            # Size is checked BEFORE the type, so an oversized upload is rejected for its size.
            content = file_storage.read()
            if not content:
                return None, self._json(success=False, code="invalid_receipt",
                                        message="Receipt file must not be empty.", status=400)
            if len(content) > MAX_RECEIPT_SIZE_BYTES:
                return None, self._json(
                    success=False, code="invalid_receipt",
                    message="Receipt file exceeds the maximum allowed size of %d MB."
                            % (MAX_RECEIPT_SIZE_BYTES // (1024 * 1024)), status=400)
            mimetype, problem = self._validate_receipt_file(file_storage, content)
            if problem:
                return None, self._json(success=False, code="invalid_receipt",
                                        message=problem, status=400)
            receipts.append((file_storage.filename, mimetype, content))
        return receipts, None

    def _create_expense_attachments(self, expense, receipts):
        """Create and link *receipts* to *expense*, returning the new records.
        `res_model`/`res_id` always come from *expense*, never from the client."""
        created_attachments = request.env["ir.attachment"]
        for filename, mimetype, content in receipts:
            created_attachments |= request.env["ir.attachment"].create({
                "name": filename,
                "mimetype": mimetype,
                "datas": base64.b64encode(content),
                "res_model": "hr.expense",
                "res_id": expense.id,
            })
        return created_attachments

    @main.http.route("/api/mobile/v1/expense", type="http", auth="none",
                     methods=["POST"], csrf=False, readonly=False)
    def expense_create(self, **kwargs):
        """Create one expense from form data and, unless ``submit=false``, submit it.
        A submit failure keeps the saved draft and returns ``submit_error``; see `_submit_context`."""
        user, err = self._authenticate_expense(need_write=True)
        if err:
            return err
        employee = user.employee_id
        payload = self._expense_create_payload(kwargs)

        fields, err = self._validate_expense_fields(payload)
        if err:
            return err
        product, amount, expense_date, description, title = (
            fields["product"], fields["amount"], fields["expense_date"],
            fields["description"], fields["title"])

        # Parsed up front so a typo'd `submit` value is rejected before anything is created.
        raw_submit = payload.get("submit")
        should_submit = True
        if raw_submit not in (None, ""):
            should_submit = main.parse_bool(raw_submit)
            if should_submit is None:
                return self._json(success=False, code="invalid_submit_flag",
                                  message="submit must be true or false.", status=400)

        # Validate receipts before creating anything.
        receipts, err = self._validate_expense_receipts()
        if err:
            return err

        try:
            # Savepoint: if any step below raises, we catch it and return an error with nothing half-created.
            with request.env.cr.savepoint():
                expense = request.env["hr.expense"].create({
                    "name": title,
                    "employee_id": employee.id,
                    "product_id": product.id,
                    "quantity": 1,
                    "total_amount_currency": amount,
                    "date": expense_date,
                    "description": description or False,
                    "payment_mode": "own_account",
                })

                created_attachments = self._create_expense_attachments(expense, receipts)

                if created_attachments:
                    # Register the receipt as the record's MAIN attachment.
                    expense._message_set_main_attachment_id(created_attachments)

                # NOT submitted inside this savepoint -- see below.
        except AccessError:
            return self._json(success=False, code="expense_access_denied",
                              message="You do not have permission to create this expense.",
                              status=403)
        except (UserError, ValidationError) as exc:
            return self._json(success=False, code="expense_create_failed",
                              message=str(exc), status=400)
        except Exception:
            _logger.exception("Unable to create mobile expense for user %s", user.id)
            return self._json(success=False, code="expense_create_failed",
                              message="Unable to create this expense.", status=400)

        submit_error = None
        if should_submit:
            _submitted_state, err = self._submit_expense(expense, user)
            if err:
                # Embedded as {"code", "message"} only; the response is still a success (the expense was created).
                submit_error = {"code": err["code"], "message": err["message"]}

        state = STATUS_MAP.get(expense.state, expense.state)
        data = {
            "id": expense.id,
            "title": expense.name,
            "status": state,
            "status_display": STATUS_DISPLAY.get(state, state.title()),
            # False once submission succeeded (there is nothing left to submit).
            "can_submit": state == "draft",
            # Same flags the list carries, so the client can render the new row's actions.
            "is_editable": expense_can_edit(expense, user),
            "is_deletable": expense_can_delete(expense, user),
            "message": "Expense created successfully.",
        }
        if submit_error is not None:
            data["submit_error"] = submit_error
        return self._json(success=True, message="Expense created successfully", data=data)

    @main.http.route("/api/mobile/v1/expense", type="http", auth="none",
                     methods=["PATCH"], csrf=False, readonly=False)
    def expense_update(self, **kwargs):
        """Update the caller's own draft or submitted expense (full form, not a sparse patch).
        A submitted claim is reset, edited and resubmitted in one savepoint; `existing_attachments` prunes receipts only."""
        user, err = self._authenticate_expense(need_write=True)
        if err:
            return err
        employee = user.employee_id
        payload = self._expense_create_payload(kwargs)

        try:
            expense_id = int(payload.get("id"))
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_expense_id",
                              message="id is required and must be an integer.", status=400)

        # Scoped to the caller's OWN employee and company, exactly like the other endpoints.
        expense = request.env["hr.expense"].search([
            ("id", "=", expense_id),
            ("employee_id", "=", employee.id),
            ("employee_id.company_id", "in", self._allowed_company_ids()),
        ], limit=1)
        if not expense:
            return self._json(success=False, code="expense_not_found",
                              message="Expense not found.", status=404)
        # Gated through `expense_can_edit`, the SAME predicate published as `is_editable`.
        was_submitted = expense.state == "submitted"
        if not expense_can_edit(expense, user):
            state = STATUS_MAP.get(expense.state, expense.state)
            message = ("This expense can no longer be withdrawn for editing."
                       if was_submitted else
                       "Only a draft or pending expense can be edited.")
            return self._json(
                success=False, code="expense_not_editable",
                message=message, status=409,
                data={"id": expense.id, "status": state,
                      "status_display": STATUS_DISPLAY.get(state, state.title())})

        fields, err = self._validate_expense_fields(payload)
        if err:
            return err
        product, amount, expense_date, description, title = (
            fields["product"], fields["amount"], fields["expense_date"],
            fields["description"], fields["title"])

        receipts, err = self._validate_expense_receipts()
        if err:
            return err

        # None means the field was OMITTED: keep every existing receipt.
        existing_attachment_ids, err = self._parse_existing_attachment_ids(payload)
        if err:
            return err
        # RECEIPTS ONLY -- never the chatter's own files.
        record_attachments = self._record_own_attachments(expense)
        if existing_attachment_ids is None:
            attachments_to_keep = record_attachments
            attachments_to_delete = request.env["ir.attachment"]
        else:
            attachments_to_keep = record_attachments.filtered(
                lambda a: a.id in existing_attachment_ids)
            attachments_to_delete = record_attachments - attachments_to_keep

        if len(attachments_to_keep) + len(receipts) > MAX_RECEIPTS_PER_EXPENSE:
            return self._json(success=False, code="too_many_receipts",
                              message="A maximum of %d receipt images is allowed."
                                      % MAX_RECEIPTS_PER_EXPENSE, status=400)

        try:
            # Savepoint: matches `expense_create`; a raised error must not leave a half-applied update.
            with request.env.cr.savepoint():
                if was_submitted:
                    # Withdraw, using Odoo's OWN action.
                    expense.action_reset()

                expense.write({
                    "name": title,
                    "product_id": product.id,
                    "total_amount_currency": amount,
                    "date": expense_date,
                    "description": description or False,
                })

                if attachments_to_delete:
                    # Captured BEFORE unlink(), after which the main-attachment link is gone.
                    preview_was_deleted = (
                        expense.message_main_attachment_id in attachments_to_delete)
                    # Not sudo(): the caller already has native write access to these attachments.
                    attachments_to_delete.unlink()
                else:
                    preview_was_deleted = False

                new_attachments = self._create_expense_attachments(expense, receipts)
                if new_attachments:
                    # Same reasoning as create: register the new receipt as the main attachment.
                    expense._message_set_main_attachment_id(new_attachments)
                elif preview_was_deleted and attachments_to_keep:
                    # The deleted attachment was the preview and nothing new was added: promote a kept one.
                    expense._message_set_main_attachment_id(
                        attachments_to_keep, force=True)

                if was_submitted:
                    # Hand it straight back via the same shared submit call as `POST /expense/create`.
                    _state, submit_err = self._submit_expense(expense, user)
                    if submit_err:
                        # Raised INSIDE the savepoint on purpose: it rolls the whole update back.
                        raise UserError(submit_err["message"])
        except AccessError:
            return self._json(success=False, code="expense_access_denied",
                              message="You do not have permission to edit this expense.",
                              status=403)
        except (UserError, ValidationError) as exc:
            return self._json(success=False, code="expense_update_failed",
                              message=str(exc), status=400)
        except Exception:
            _logger.exception("Unable to update mobile expense %s for user %s",
                              expense_id, user.id)
            return self._json(success=False, code="expense_update_failed",
                              message="Unable to update this expense.", status=400)

        state = STATUS_MAP.get(expense.state, expense.state)
        return self._json(success=True, message="Expense updated successfully", data={
            "id": expense.id,
            "title": expense.name,
            "status": state,
            "status_display": STATUS_DISPLAY.get(state, state.title()),
            # Read from the record, not assumed.
            "can_submit": state == "draft",
            # Same flags the list carries, so the client can re-render this row from the response.
            "is_editable": expense_can_edit(expense, user),
            "is_deletable": expense_can_delete(expense, user),
            "message": "Expense updated successfully.",
        })

    @main.http.route("/api/mobile/v1/expense/<expense_id>/submit",
                     type="http", auth="none", methods=["POST"], csrf=False,
                     readonly=False)
    def expense_submit(self, expense_id, **kwargs):
        """Submit one of the caller's own draft expenses for approval.
        Runs Odoo's own `action_submit()`, so its approver rules still apply."""
        try:
            expense_id = int(expense_id)
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_expense_id",
                              message="expense_id must be an integer.", status=400)

        user, err = self._authenticate_expense(need_write=True)
        if err:
            return err
        employee = user.employee_id

        # Scoped to the caller's OWN employee and company, exactly like every other endpoint.
        expense = request.env["hr.expense"].sudo().search([
            ("id", "=", expense_id),
            ("employee_id", "=", employee.id),
            ("employee_id.company_id", "in", self._allowed_company_ids()),
        ], limit=1)
        if not expense:
            return self._json(success=False, code="expense_not_found",
                              message="Expense not found.", status=404)

        if expense.state != "draft":
            # Not an error the user can act on twice: report where it already is.
            state = STATUS_MAP.get(expense.state, expense.state)
            return self._json(
                success=False, code="expense_not_draft",
                message="This expense has already been submitted.",
                status=409, data={
                    "id": expense.id,
                    "status": state,
                    "status_display": STATUS_DISPLAY.get(state, state.title()),
                })

        state, err = self._submit_expense(expense, user)
        if err:
            return self._json(success=False, code=err["code"], message=err["message"],
                              status=err["status"])
        return self._json(success=True, message="Expense submitted successfully", data={
            "id": expense.id,
            "title": expense.name,
            "status": state,
            "status_display": STATUS_DISPLAY.get(state, state.title()),
            "message": "Expense submitted successfully.",
        })

    @main.http.route(["/api/mobile/v1/expenses/<expense_id>",
                      "/api/mobile/v1/expense/<expense_id>"],
                     type="http", auth="none", methods=["DELETE"], csrf=False,
                     readonly=False)
    def expense_delete(self, expense_id, **kwargs):
        """Delete the caller's own draft or submitted expense; foreign ids return 404.
        Attachments are unlinked first, since core leaves `hr.expense` attachments orphaned."""
        try:
            expense_id = int(expense_id)
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_expense_id",
                              message="expense_id must be an integer.", status=400)

        user, err = self._authenticate_expense(need_write=True)
        if err:
            return err
        employee = user.employee_id

        expense = request.env["hr.expense"].search([
            ("id", "=", expense_id),
            ("employee_id", "=", employee.id),
            ("employee_id.company_id", "in", self._allowed_company_ids()),
        ], limit=1)
        if not expense:
            return self._json(success=False, code="expense_not_found",
                              message="Expense not found.", status=404)

        # Gated through `expense_can_delete`, the SAME predicate published as `is_deletable`.
        was_submitted = expense.state == "submitted"
        if not expense_can_delete(expense, user):
            state = STATUS_MAP.get(expense.state, expense.state)
            message = ("This expense can no longer be withdrawn for deletion."
                       if was_submitted else
                       "Only a draft or pending expense can be deleted.")
            return self._json(
                success=False, code="expense_not_deletable",
                message=message,
                status=409, data={
                    "id": expense.id,
                    "status": state,
                    "status_display": STATUS_DISPLAY.get(state, state.title()),
                })

        # Read before the delete: afterwards the record is gone and these would raise.
        deleted_id, deleted_title = expense.id, expense.name

        try:
            # Savepoint, matching create/update: a failure part-way must not leave a half-deleted record.
            with request.env.cr.savepoint():
                if was_submitted:
                    # Withdraw first, using Odoo's own action, so the claim is back in `draft` before deletion.
                    expense.action_reset()
                expense.attachment_ids.unlink()
                expense.unlink()
        except AccessError:
            return self._json(success=False, code="expense_access_denied",
                              message="You do not have permission to delete this expense.",
                              status=403)
        except (UserError, ValidationError) as exc:
            return self._json(success=False, code="expense_delete_failed",
                              message=str(exc), status=400)
        except Exception:
            _logger.exception("Unable to delete mobile expense %s for user %s",
                              expense_id, user.id)
            return self._json(success=False, code="expense_delete_failed",
                              message="Unable to delete this expense.", status=400)

        return self._json(success=True, message="Expense deleted successfully", data={
            "id": deleted_id,
            "title": deleted_title,
            "message": "Expense deleted successfully.",
        })

    def _submit_context(self, expense, user):
        """Context for `action_submit()` that blocks self-approval for non-admins.
        Shared by every submit path so create, edit and submit agree."""
        if user.has_group(SELF_APPROVE_GROUP):
            return {}
        if not self._has_no_approver_at_all(expense):
            return {}
        return {"mobile_block_self_approval": True}

    def _has_no_approver_at_all(self, expense):
        """True when nobody resolves as an approver for this expense.
        sudo() is a read-only check of approver config and can only withhold approval."""
        expense = expense.sudo()
        if expense.employee_id.expense_manager_id:
            return False
        return not expense._get_default_responsible_for_approval()

    def _submit_expense(self, expense, user):
        """Run ``action_submit()`` on *expense*; return ``(status, None)`` or ``(None, error)``.
        *error* is a plain ``{code, message, status}`` dict so callers can wrap or embed it."""
        try:
            with request.env.cr.savepoint():
                expense.sudo().with_context(
                    **self._submit_context(expense, user)
                ).action_submit()
        except AccessError:
            return None, {"code": "expense_access_denied",
                          "message": "You do not have permission to submit this expense.",
                          "status": 403}
        except (UserError, ValidationError) as exc:
            return None, {"code": "expense_submit_failed", "message": str(exc), "status": 400}
        except Exception:
            _logger.exception(
                "Unable to submit mobile expense %s for user %s", expense.id, user.id)
            return None, {"code": "expense_submit_failed",
                          "message": "Unable to submit this expense.", "status": 400}
        return STATUS_MAP.get(expense.state, expense.state), None
