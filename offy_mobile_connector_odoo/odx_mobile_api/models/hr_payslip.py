import logging

from odoo import api, models

from ..notifications import NOTIFICATION_TITLES, PAYSLIP_AVAILABLE

_logger = logging.getLogger(__name__)

# Must mirror VISIBLE_STATES in controllers/payslip.py.
VISIBLE_STATES = ("validated", "paid")

PAYSLIP_FEATURE_CODE = "payslip"
# Re-exported from ../notifications.py so the model and the inbox endpoint share one type.
PAYSLIP_NOTIFICATION_TYPE = PAYSLIP_AVAILABLE


class HrPayslip(models.Model):
    """Queue a "Payslip Available" push when a payslip first enters ``VISIBLE_STATES``.
    Lives in the API layer, keeping the connector core business-agnostic."""

    _name = "hr.payslip"
    _inherit = ["hr.payslip", "mobile.notify.mixin"]

    @api.model_create_multi
    def create(self, vals_list):
        """Notify for a payslip created already visible (imports, some payroll flows)."""
        payslips = super().create(vals_list)
        born_visible = payslips.filtered(lambda p: p.state in VISIBLE_STATES)
        if born_visible:
            try:
                born_visible._notify_mobile_payslip_available()
            except Exception:
                _logger.exception(
                    "Unexpected error while queueing payslip availability "
                    "notifications on create; the payslip was still created."
                )
        return payslips

    def write(self, vals):
        # Snapshot pre-write states only when this write could make a payslip newly visible.
        track_visibility = "state" in vals and vals["state"] in VISIBLE_STATES
        before_states = {p.id: p.state for p in self} if track_visibility else None

        res = super().write(vals)

        if before_states:
            newly_visible = self.filtered(
                lambda p: p.state in VISIBLE_STATES
                and before_states.get(p.id) not in VISIBLE_STATES
            )
            if newly_visible:
                # Never let notification plumbing block payroll validation.
                try:
                    newly_visible._notify_mobile_payslip_available()
                except Exception:
                    _logger.exception(
                        "Unexpected error while sending payslip availability "
                        "push notifications; payroll write already committed."
                    )
        return res

    def unlink(self):
        # Capture before the rows go: deleting a visible payslip must clear the home card.
        employees = self.filtered(
            lambda p: p.state in VISIBLE_STATES).mapped("employee_id")
        res = super().unlink()
        if employees:
            self._sync_mobile_home_for_employees(
                employees, ["payslip"], reason="payslip_deleted")
        return res

    def _notify_mobile_payslip_available(self):
        """Queue the availability notification for each payslip.
        Guards live in ``mobile.notify.mixin``; only the period label, never amounts, is sent."""
        for payslip in self:
            period = payslip._mobile_period_label()
            payslip._queue_mobile_notification(
                payslip.employee_id,
                PAYSLIP_FEATURE_CODE,
                PAYSLIP_NOTIFICATION_TYPE,
                NOTIFICATION_TITLES[PAYSLIP_AVAILABLE],
                "Your payslip for %s is now available." % period,
                data={
                    "payslip_id": payslip.id,
                    "period": period,
                    "action": "open_payslip_detail",
                },
                # Payroll can re-validate a payslip; write_date keeps each availability event distinct.
                dedup_key="payslip:%s:%s:%s" % (
                    payslip.id, payslip.state, payslip.write_date or ""),
            )
            payslip._sync_mobile_home(
                payslip.employee_id, ["payslip"], reason="payslip_available")

    def _mobile_period_label(self):
        self.ensure_one()
        return self.date_from.strftime("%B %Y") if self.date_from else self.name

    def _mobile_user_can_read_payslip_feature(self, user):
        """Back-compat wrapper around ``mobile.notify.mixin._mobile_user_for_employee``."""
        if not user:
            return False
        feature = self.env["mobile.feature"].sudo().search(
            [("code", "=", PAYSLIP_FEATURE_CODE), ("active", "=", True)], limit=1
        )
        if not feature:
            return False
        return bool(self.env["mobile.user.feature"].sudo().search_count(
            [("user_id", "=", user.id), ("feature_id", "=", feature.id)]
        ))
