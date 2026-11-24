from odoo import fields
from odoo.tests import common as odoo_common


class HttpCase(odoo_common.HttpCase):
    """Odoo 18 `HttpCase` whose `url_open` also takes Odoo 19's `json`, `params`, `cookies` and `method`."""

    def url_open(self, url, data=None, files=None, timeout=12, headers=None,
                 allow_redirects=True, head=False, json=None, params=None,
                 cookies=None, method=None):
        if json is None and params is None and cookies is None and method is None:
            return super().url_open(url, data=data, files=files, timeout=timeout,
                                    headers=headers, allow_redirects=allow_redirects,
                                    head=head)
        if url.startswith('/'):
            url = self.base_url() + url
        if not method:
            method = 'HEAD' if head else (
                'POST' if (data or files or json is not None) else 'GET')
        return self.opener.request(
            method, url, data=data, files=files, json=json, params=params,
            cookies=cookies, timeout=timeout, headers=headers,
            allow_redirects=False if head else allow_redirects)


def set_expense_state(expense, state):
    """Drive *expense* to the Odoo 18 *state* through its expense sheet.

    `hr.expense.state` is computed from `sheet_id.state`, so approval lives on
    `hr.expense.sheet`. Supports draft, reported, submitted, approved, refused.
    Flushes so the stored compute (and the mobile hooks on it) runs now.
    """
    expense = expense.sudo()
    if state != "draft":
        # Odoo 18 picks the sheet's journal from env.company, so create it in the expense's company.
        sheet = expense.sheet_id or expense.with_company(
            expense.company_id)._create_sheets_from_expense()
        if state == "submitted":
            sheet.action_submit_sheet()
        elif state == "approved":
            sheet.write({"approval_state": "approve",
                         "approval_date": fields.Datetime.now()})
        elif state == "refused":
            sheet.write({"approval_state": "cancel"})
        elif state != "reported":
            raise ValueError("unsupported expense state: %s" % state)
    expense.env.flush_all()
    return expense
