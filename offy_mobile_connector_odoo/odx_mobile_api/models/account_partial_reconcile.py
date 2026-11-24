import logging

from odoo import api, models

_logger = logging.getLogger(__name__)


class AccountPartialReconcile(models.Model):
    """Turns "money was allocated to an expense" into a mobile notification, once per reimbursement instalment.
    Expense state and move payment_state stop changing after the first instalment, and amount_residual is a compute.
    """

    _inherit = "account.partial.reconcile"

    @api.model_create_multi
    def create(self, vals_list):
        partials = super().create(vals_list)
        partials._notify_mobile_expense_payments()
        return partials

    def _notify_mobile_expense_payments(self):
        """Notify the employees behind any expenses these partials touch; never raises.
        Both sides are inspected because the expense line can be on either the debit or credit side.
        """
        try:
            lines = self.debit_move_id | self.credit_move_id
            expenses = lines.move_id.expense_ids
            if expenses:
                expenses._notify_mobile_expense_payments()
        except Exception:
            _logger.exception(
                "Failed to notify mobile expense payments for partial "
                "reconciles %s.", self.ids)
