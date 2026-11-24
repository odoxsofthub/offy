from odoo.tests import HttpCase, tagged
from odoo.tests.common import BaseCase

from ..controllers.main import amount_2dp

PASSWORD = "amount_2dp_pw_1234"
LOGIN = "amount_2dp_user@test.com"


@tagged("-at_install", "post_install")
class TestAmount2dpHelper(BaseCase):
    """`amount_2dp`: the formatter behind `net_pay` and `final_amount`."""

    def test_whole_amount_keeps_two_zeros(self):
        self.assertEqual(amount_2dp(32000.0), "32000.00")

    def test_integer(self):
        self.assertEqual(amount_2dp(5), "5.00")

    def test_one_decimal(self):
        self.assertEqual(amount_2dp(12.3), "12.30")

    def test_more_than_two_decimals_rounds_half_up(self):
        self.assertEqual(amount_2dp(2.345), "2.35")
        self.assertEqual(amount_2dp(2.344), "2.34")

    def test_negatives(self):
        self.assertEqual(amount_2dp(-150.0), "-150.00")
        self.assertEqual(amount_2dp(-2.345), "-2.35")

    def test_rounding_to_zero_is_never_negative_zero(self):
        self.assertEqual(amount_2dp(-0.001), "0.00")
        self.assertEqual(amount_2dp(0.0), "0.00")

    def test_missing_values_are_returned_unchanged(self):
        self.assertIsNone(amount_2dp(None))
        self.assertIs(amount_2dp(False), False)

    def test_non_numbers_are_returned_unchanged(self):
        self.assertEqual(amount_2dp("n/a"), "n/a")


@tagged("-at_install", "post_install")
class TestAmount2dpEndpoints(HttpCase):
    """`net_pay` (GET /payslip, every occurrence) and `final_amount`
    (GET /home, payslip card) are two-decimal strings; nothing else moves."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        cls.user = cls.env["res.users"].sudo().create({
            "name": "Amount 2dp User",
            "login": LOGIN,
            "password": PASSWORD,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = cls.env["hr.employee"].sudo().create({
            "name": "Amount 2dp User",
            "company_id": cls.env.ref("base.main_company").id,
            "user_id": cls.user.id,
        })

    def _payslip(self, date_from, date_to, net_wage):
        """A visible payslip with a fixed net. State and net are written
        directly: the payroll compute is not under test here."""
        payslip = self.env["hr.payslip"].sudo().create({
            "name": "Payslip %s" % date_to,
            "employee_id": self.employee.id,
            "date_from": date_from,
            "date_to": date_to,
        })
        # Flush first: the pending `net_wage` recompute would otherwise be
        # written after this UPDATE and reset the net to 0.
        self.env.flush_all()
        self.env.cr.execute(
            "UPDATE hr_payslip SET state = 'validated', net_wage = %s WHERE id = %s",
            [net_wage, payslip.id])
        self.env.invalidate_all()
        return payslip

    def _get(self, path):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": LOGIN, "password": PASSWORD},
            headers={"Content-Type": "application/json"},
        )
        token = resp.json()["data"]["token"]
        resp = self.url_open(
            path, headers={"Authorization": "Bearer %s" % token})
        body = resp.json()
        self.assertEqual(resp.status_code, 200, body)
        self.assertTrue(body["success"], body)
        return body["data"]

    # GET /api/mobile/v1/payslip -> net_pay
    def test_payslip_net_pay_has_two_decimals(self):
        self._payslip("2026-08-01", "2026-08-31", 32000.0)
        data = self._get("/api/mobile/v1/payslip")
        self.assertEqual(data["net_pay"], "32000.00")

    def test_every_history_item_is_formatted(self):
        self._payslip("2026-06-01", "2026-06-30", 5)
        self._payslip("2026-07-01", "2026-07-31", 1234.5)
        self._payslip("2026-08-01", "2026-08-31", 32000.0)
        data = self._get("/api/mobile/v1/payslip")
        self.assertEqual(data["net_pay"], "32000.00")
        self.assertEqual([item["net_pay"] for item in data["history"]],
                         ["1234.50", "5.00"])

    def test_payslip_other_amounts_are_unchanged(self):
        """Only `net_pay` changes type; line amounts stay numbers."""
        self._payslip("2026-08-01", "2026-08-31", 32000.0)
        data = self._get("/api/mobile/v1/payslip")
        for line in data["lines"]:
            self.assertNotIsInstance(line.get("total"), str)

    def test_payslip_without_payslips_is_unchanged(self):
        """No payslip -> the same empty payload as before, no crash."""
        data = self._get("/api/mobile/v1/payslip")
        self.assertEqual(data, {"latest": None, "history": []})

    def test_payslip_with_a_null_net_does_not_crash(self):
        """A NULL `net_wage` column. Odoo reads a NULL float as 0.0, so the
        API serves "0.00" rather than failing."""
        self._payslip("2026-08-01", "2026-08-31", None)
        data = self._get("/api/mobile/v1/payslip")
        self.assertEqual(data["net_pay"], "0.00")

    # GET /api/mobile/v1/home -> payslip.final_amount
    def test_home_final_amount_has_two_decimals(self):
        self._payslip("2026-08-01", "2026-08-31", 32000.0)
        card = self._get("/api/mobile/v1/home")["home"]["payslip"]
        self.assertEqual(card["final_amount"], "32000.00")

    def test_home_final_amount_is_none_without_a_payslip(self):
        card = self._get("/api/mobile/v1/home")["home"]["payslip"]
        self.assertIsNone(card["final_amount"])
        self.assertIsNone(card["month"])

    def test_home_other_amounts_are_unchanged(self):
        """The expense card's `total_amount` stays a number."""
        self._payslip("2026-08-01", "2026-08-31", 32000.0)
        home = self._get("/api/mobile/v1/home")["home"]
        self.assertNotIsInstance(home["expense"]["total_amount"], str)
