from datetime import date
from unittest.mock import patch

from odoo.tests import TransactionCase, tagged


@tagged("post_install", "-at_install")
class TestPayslipNotification(TransactionCase):
    """Payslip Available push trigger: eligibility, dedup on re-transition and payroll safety.
    ``queue_once_to_user`` is mocked; delivery is tested in odx_mobile_connector."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.user = cls.env["res.users"].create({
            "name": "Payslip Mobile User",
            "login": "payslip_push_user@test.com",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = cls.env["hr.employee"].create({
            "name": "Payslip Mobile User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })

        cls.non_mobile_user = cls.env["res.users"].create({
            "name": "Non Mobile User",
            "login": "payslip_push_nonmobile@test.com",
            "group_ids": [(4, internal_group.id)],
        })
        cls.non_mobile_employee = cls.env["hr.employee"].create({
            "name": "Non Mobile User",
            "company_id": company.id,
            "user_id": cls.non_mobile_user.id,
        })

        cls.employee_no_user = cls.env["hr.employee"].create({
            "name": "No User Employee",
            "company_id": company.id,
        })

        cls.feature = cls.env["mobile.feature"].search([("code", "=", "payslip")], limit=1)

    def _make_payslip(self, employee):
        # Explicit name/date range: otherwise computed from a contract, causing a NOT NULL failure.
        return self.env["hr.payslip"].create({
            "employee_id": employee.id,
            "name": "Test Payslip - %s" % employee.name,
            "date_from": date(2026, 6, 1),
            "date_to": date(2026, 6, 30),
        })

    def test_payslip_feature_exists_and_active(self):
        self.assertTrue(self.feature)
        self.assertTrue(self.feature.active)
        self.assertEqual(self.feature.name, "Payslip")

    def test_mobile_user_with_access_is_notified(self):
        payslip = self._make_payslip(self.employee)
        with patch.object(
            type(self.env["mobile.push.service"]), "queue_once_to_user"
        ) as send_mock:
            payslip.write({"state": "validated"})

        send_mock.assert_called_once()
        args, kwargs = send_mock.call_args
        self.assertEqual(args[0], self.user)
        self.assertEqual(args[1], "payslip_available")
        self.assertEqual(args[2], "hr.payslip")
        self.assertEqual(args[3], payslip.id)

    def test_non_mobile_user_is_not_notified(self):
        payslip = self._make_payslip(self.non_mobile_employee)
        with patch.object(
            type(self.env["mobile.push.service"]), "queue_once_to_user"
        ) as send_mock:
            payslip.write({"state": "validated"})

        send_mock.assert_not_called()

    def test_unlinked_feature_is_not_notified(self):
        # Access is deny-by-default; removing the auto-created feature row revokes Payslip.
        self.env["mobile.user.feature"].search([
            ("user_id", "=", self.user.id), ("feature_id", "=", self.feature.id),
        ]).unlink()
        payslip = self._make_payslip(self.employee)
        with patch.object(
            type(self.env["mobile.push.service"]), "queue_once_to_user"
        ) as send_mock:
            payslip.write({"state": "validated"})

        send_mock.assert_not_called()

    def test_feature_inactive_is_not_notified(self):
        self.feature.active = False
        try:
            payslip = self._make_payslip(self.employee)
            with patch.object(
                type(self.env["mobile.push.service"]), "queue_once_to_user"
            ) as send_mock:
                payslip.write({"state": "validated"})
            send_mock.assert_not_called()
        finally:
            self.feature.active = True

    def test_payslip_without_linked_user_does_not_crash(self):
        payslip = self._make_payslip(self.employee_no_user)
        with patch.object(
            type(self.env["mobile.push.service"]), "queue_once_to_user"
        ) as send_mock:
            payslip.write({"state": "validated"})  # must not raise

        send_mock.assert_not_called()
        self.assertEqual(payslip.state, "validated")

    def test_draft_to_validated_triggers_once(self):
        payslip = self._make_payslip(self.employee)
        with patch.object(
            type(self.env["mobile.push.service"]), "queue_once_to_user"
        ) as send_mock:
            payslip.write({"state": "validated"})
        send_mock.assert_called_once()

    def test_validated_to_paid_does_not_retrigger(self):
        payslip = self._make_payslip(self.employee)
        payslip.write({"state": "validated"})  # already visible, real call (push disabled by default: safe no-op)

        with patch.object(
            type(self.env["mobile.push.service"]), "queue_once_to_user"
        ) as send_mock:
            payslip.write({"state": "paid"})

        send_mock.assert_not_called()

    def test_draft_directly_to_paid_triggers(self):
        payslip = self._make_payslip(self.employee)
        with patch.object(
            type(self.env["mobile.push.service"]), "queue_once_to_user"
        ) as send_mock:
            payslip.write({"state": "paid"})
        send_mock.assert_called_once()

    def test_cancel_does_not_trigger(self):
        payslip = self._make_payslip(self.employee)
        with patch.object(
            type(self.env["mobile.push.service"]), "queue_once_to_user"
        ) as send_mock:
            payslip.write({"state": "cancel"})
        send_mock.assert_not_called()

    def test_notification_content_has_no_salary_data(self):
        payslip = self._make_payslip(self.employee)
        with patch.object(
            type(self.env["mobile.push.service"]), "queue_once_to_user"
        ) as send_mock:
            payslip.write({"state": "validated"})

        args, kwargs = send_mock.call_args
        title, body = args[4], args[5]
        data = kwargs.get("data") or (args[6] if len(args) > 6 else None)
        blob = "%s %s %s" % (title, body, data)
        for forbidden in ("net_wage", "gross", "salary", "deduction", "bank"):
            self.assertNotIn(forbidden, blob.lower())
        self.assertEqual(data["type"], "payslip_available")
        self.assertEqual(data["feature"], "payslip")
        self.assertEqual(data["payslip_id"], payslip.id)

    def test_push_disabled_does_not_block_payroll(self):
        # No Firebase credentials by default, so the real queue_once_to_user call no-ops.
        payslip = self._make_payslip(self.employee)
        payslip.write({"state": "validated"})  # must not raise
        self.assertEqual(payslip.state, "validated")

    def test_notification_exception_does_not_block_payroll(self):
        payslip = self._make_payslip(self.employee)
        with patch.object(
            type(self.env["mobile.push.service"]), "queue_once_to_user",
            side_effect=RuntimeError("boom"),
        ):
            payslip.write({"state": "validated"})  # must not raise/propagate

        self.assertEqual(payslip.state, "validated")
