from datetime import date

from odoo.tests import TransactionCase, tagged

from ..controllers.payslip import MobileApiPayslip


@tagged("post_install", "-at_install")
class TestPayslipLines(TransactionCase):
    """`lines` must match the printed payslip: every `appears_on_payslip` line, in order,
    with no category allowlist (e.g. US TAXES lines must count as deductions)."""

    @staticmethod
    def _ancestry_codes(category):
        """Category codes up to the root. Restated (not imported) so the
        fixture proves its own invariant without the code under test."""
        codes = []
        while category:
            codes.append(category.code)
            category = category.parent_id
        return codes

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.controller = MobileApiPayslip()
        company = cls.env.ref("base.main_company")
        cls.employee = cls.env["hr.employee"].create({
            "name": "Payslip Lines Employee",
            "company_id": company.id,
        })

        Category = cls.env["hr.salary.rule.category"]
        Rule = cls.env["hr.salary.rule"]
        # `type_id` is NOT NULL on hr.payroll.structure; reuse an existing type.
        structure_type = cls.env["hr.payroll.structure.type"].search([], limit=1)
        if not structure_type:
            structure_type = cls.env["hr.payroll.structure.type"].create({
                "name": "Payslip Lines Type",
            })
        cls.structure = cls.env["hr.payroll.structure"].create({
            "name": "Payslip Lines Structure",
            "type_id": structure_type.id,
            "country_id": False,
        })

        def category(code, name, parent=None):
            """Find or create a category. `parent` matters: the buckets walk
            the ANCESTRY, so a deduction needs `DED` above it."""
            found = Category.search([("code", "=", code)], limit=1)
            if not found:
                found = Category.create({
                    "code": code,
                    "name": name,
                    "parent_id": parent.id if parent else False,
                })
            elif parent and parent.code not in cls._ancestry_codes(found):
                # Found but shaped wrong; rolled back with the transaction.
                found.parent_id = parent
            return found

        cls.cat_basic = category("BASIC", "Basic")
        cls.cat_ded = category("DED", "Deduction")
        # Outside the legacy allowlist but under DED, so the ancestry walk treats it as a deduction.
        cls.cat_taxes = category("TAXES", "Taxes", parent=cls.cat_ded)
        cls.cat_net = category("NET", "Net")

        assert "DED" in cls._ancestry_codes(cls.cat_taxes), (
            "fixture invariant: TAXES must roll up to DED")

        def rule(code, name, category_rec, amount, sequence, **extra):
            values = {
                "name": name,
                "code": code,
                "category_id": category_rec.id,
                "struct_id": cls.structure.id,
                "sequence": sequence,
                "amount_select": "fix",
                "amount_fix": amount,
            }
            values.update(extra)
            return Rule.create(values)

        cls.rule_basic = rule("BASIC", "Basic Salary", cls.cat_basic, 1000.0, 1)
        cls.rule_tax = rule("TAX", "Income Tax", cls.cat_taxes, -150.0, 100)
        cls.rule_net = rule("NET", "Net Salary", cls.cat_net, 850.0, 200)
        # Never printed -- the PDF filters it out, so the API must too.
        cls.rule_hidden = rule(
            "EMPLOYERCOST", "Employer Cost", cls.cat_taxes, 75.0, 150,
            appears_on_payslip=False)
        # A heading row: Odoo prints its text and no figure.
        cls.rule_title = rule(
            "SECTION", "Deductions", cls.cat_taxes, 0.0, 90, title=True)

        cls.payslip = cls.env["hr.payslip"].create({
            "employee_id": cls.employee.id,
            "name": "Payslip Lines Test",
            "date_from": date(2026, 6, 1),
            "date_to": date(2026, 6, 30),
            "struct_id": cls.structure.id,
        })
        cls.payslip.compute_sheet()
        cls.env.flush_all()

    def _lines(self):
        return self.controller._payslip_lines(self.payslip)

    def _codes(self, lines=None):
        return [line["code"] for line in (lines or self._lines())]

    def test_lines_match_the_pdf_selection_exactly(self):
        """Same rows the report's own filter would produce."""
        expected = self.payslip.line_ids.filtered(
            lambda line: line.appears_on_payslip)
        self.assertEqual(self._codes(), expected.mapped("code"))

    def test_lines_keep_the_documents_order(self):
        """`line_ids` is sequence-ordered; the app must not have to re-sort."""
        lines = self._lines()
        self.assertEqual(
            [line["sequence"] for line in lines],
            sorted(line["sequence"] for line in lines))

    def test_lines_excluded_from_the_printed_payslip_are_not_served(self):
        self.assertNotIn("EMPLOYERCOST", self._codes())

    def test_categories_outside_the_legacy_allowlist_are_served(self):
        """A TAXES-category line reaches the client."""
        self.assertIn("TAX", self._codes())

    def _earnings(self):
        return self.controller._payslip_amount_buckets(self.payslip)["earnings"]

    def _deductions(self):
        return self.controller._payslip_amount_buckets(self.payslip)["deductions"]

    def test_deduction_outside_the_DED_category_is_still_a_deduction(self):
        """A deduction outside the DED category is still a deduction."""
        self.assertEqual(
            [line["code"] for line in self._deductions()], ["TAX"])
        self.assertAlmostEqual(self._deductions()[0]["amount"], -150.0, places=2)

    def test_earnings_carry_the_positive_lines(self):
        self.assertIn("BASIC", [line["code"] for line in self._earnings()])

    def test_aggregate_rows_are_not_listed_as_earnings(self):
        """Aggregate rows such as NET are not listed as earnings (would double-count)."""
        self.assertNotIn("NET", [line["code"] for line in self._earnings()])

    def test_title_rows_are_in_neither_bucket(self):
        """A heading prints as text with no figure, so it is not money."""
        codes = ([line["code"] for line in self._earnings()]
                 + [line["code"] for line in self._deductions()])
        self.assertNotIn("SECTION", codes)

    def test_rows_hidden_from_the_payslip_are_in_neither_bucket(self):
        """Employer cost never reaches the employee's document, or the app."""
        codes = ([line["code"] for line in self._earnings()]
                 + [line["code"] for line in self._deductions()])
        self.assertNotIn("EMPLOYERCOST", codes)

    def test_buckets_reconcile_with_net_pay(self):
        """Earnings plus deductions equal the net pay."""
        total = (sum(line["amount"] for line in self._earnings())
                 + sum(line["amount"] for line in self._deductions()))
        self.assertAlmostEqual(total, self.payslip.net_wage, places=2)

    def test_buckets_are_a_subset_of_the_printed_lines(self):
        """Nothing may appear in a bucket that the document does not print."""
        printed = set(self._codes())
        for line in self._earnings() + self._deductions():
            self.assertIn(line["code"], printed)

    def test_served_lines_reconcile_with_net_pay(self):
        """Served lines reconcile with the net pay shown beside them."""
        by_code = {line["code"]: line["total"] for line in self._lines()}
        self.assertAlmostEqual(
            by_code["BASIC"] + by_code["TAX"], by_code["NET"], places=2)

    def test_line_carries_category_code_and_name(self):
        tax = next(line for line in self._lines() if line["code"] == "TAX")
        self.assertEqual(tax["category"]["code"], "TAXES")
        self.assertTrue(tax["category"]["name"])

    def test_line_carries_the_printed_columns(self):
        tax = next(line for line in self._lines() if line["code"] == "TAX")
        for key in ("sequence", "code", "name", "amount", "quantity",
                    "rate", "total", "is_title"):
            self.assertIn(key, tax)
        self.assertAlmostEqual(tax["total"], -150.0, places=2)

    def test_title_rows_are_flagged(self):
        """Title rows are flagged so the client does not render a 0.00 figure."""
        section = next(
            (line for line in self._lines() if line["code"] == "SECTION"), None)
        self.assertIsNotNone(section, "the title rule should still be printed")
        self.assertTrue(section["is_title"])
        self.assertFalse(
            next(line for line in self._lines()
                 if line["code"] == "BASIC")["is_title"])

    def test_ytd_is_omitted_when_the_structure_does_not_compute_it(self):
        """Mirrors the report's own `t-if="o.ytd_computation"` column."""
        self.assertFalse(self.payslip.ytd_computation)
        for line in self._lines():
            self.assertNotIn("ytd", line)

    def test_ytd_is_served_when_the_structure_computes_it(self):
        self.structure.ytd_computation = True
        self.env.flush_all()
        self.assertTrue(self.payslip.ytd_computation)
        for line in self._lines():
            self.assertIn("ytd", line)
