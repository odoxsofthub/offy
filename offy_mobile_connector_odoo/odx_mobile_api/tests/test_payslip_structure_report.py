from odoo.tests import TransactionCase, tagged

from ..controllers.payslip import PAYSLIP_REPORT, MobileApiPayslip


@tagged("post_install", "-at_install")
class TestPayslipStructureReport(TransactionCase):
    """The app's payslip PDF must be the report the backend prints for that salary structure.
    Pinned as equivalence with core's `hr.payslip._get_pdf_reports()`, not a hardcoded id."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.controller = MobileApiPayslip()
        cls.default_report = cls.env.ref(PAYSLIP_REPORT)

    def _structure_with_report(self, report):
        """A throwaway structure pinned to *report*; `report_id` defaults to the generic one, so clear it for none."""
        structure_type = self.env["hr.payroll.structure.type"].search([], limit=1)
        return self.env["hr.payroll.structure"].create({
            "name": "Structure Report Test",
            "type_id": structure_type.id,
            "report_id": report.id if report else False,
        })

    def _payslip_on(self, structure):
        employee = self.env["hr.employee"].create({
            "name": "Structure Report Employee",
            "company_id": self.env.ref("base.main_company").id,
        })
        return self.env["hr.payslip"].create({
            "name": "Structure Report Slip",
            "employee_id": employee.id,
            "struct_id": structure.id,
        })

    def test_structure_template_is_used_over_the_default(self):
        """A structure naming its own template must win."""
        other = self.env["ir.actions.report"].search([
            ("model", "=", "hr.payslip"),
            ("report_type", "=", "qweb-pdf"),
            ("id", "!=", self.default_report.id),
        ], limit=1)
        if not other:
            self.skipTest("no second hr.payslip report installed to test with")

        payslip = self._payslip_on(self._structure_with_report(other))
        self.assertEqual(
            self.controller._payslip_report_action(payslip),
            other,
            "the payslip must render with the template its salary structure "
            "names, not the module default.",
        )

    def test_falls_back_to_default_when_structure_names_none(self):
        payslip = self._payslip_on(self._structure_with_report(False))
        self.assertEqual(
            self.controller._payslip_report_action(payslip),
            self.default_report,
        )

    def test_matches_core_for_every_existing_payslip(self):
        """On real data, the mobile report matches `hr.payslip._get_pdf_reports()`."""
        payslips = self.env["hr.payslip"].search([], limit=200)
        if not payslips:
            self.skipTest("no payslips in this database")

        core_for = {}
        for report, group in payslips._get_pdf_reports().items():
            for slip in group:
                core_for[slip.id] = report

        for slip in payslips:
            self.assertEqual(
                self.controller._payslip_report_action(slip),
                core_for[slip.id],
                "payslip %s renders a different report in the app (%s) than "
                "the backend prints (%s)" % (
                    slip.id,
                    self.controller._payslip_report_action(slip).report_name,
                    core_for[slip.id].report_name,
                ),
            )
