"""Catalogue of every mobile push notification type, shared by model triggers and the inbox endpoint.
Free of Odoo imports so models and controllers can both import it without a cycle."""

PAYSLIP_AVAILABLE = "payslip_available"
TIMEOFF_APPROVED = "timeoff_approved"
TIMEOFF_REFUSED = "timeoff_refused"
EXPENSE_APPROVED = "expense_approved"
EXPENSE_REFUSED = "expense_refused"
EXPENSE_PAID = "expense_paid"
EXPENSE_PARTIALLY_PAID = "expense_partially_paid"

NOTIFICATION_TITLES = {
    PAYSLIP_AVAILABLE: "Payslip Available",
    TIMEOFF_APPROVED: "Time Off Approved",
    TIMEOFF_REFUSED: "Time Off Refused",
    EXPENSE_APPROVED: "Expense Approved",
    EXPENSE_REFUSED: "Expense Refused",
    EXPENSE_PAID: "Expense Paid",
    EXPENSE_PARTIALLY_PAID: "Expense Partially Paid",
}


# The label goes in the title: push bodies are collapsed first, the title always survives.
COMPANY_TITLE_SEPARATOR = " \u00b7 "


def title_with_company(title, company_name):
    """`"Expense Approved"` + `"Company 2"` -> `"Expense Approved · Company 2"`.
    Returns *title* unchanged when there is no company to name."""
    title = title or ""
    company_name = (company_name or "").strip()
    if not company_name:
        return title
    if not title:
        return company_name
    # Idempotent: an already-labelled title must not repeat the company name.
    if title.endswith("%s%s" % (COMPANY_TITLE_SEPARATOR, company_name)):
        return title
    return "%s%s%s" % (title, COMPANY_TITLE_SEPARATOR, company_name)
