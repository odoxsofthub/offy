from odoo.tests import HttpCase, tagged

PASSWORD = "payslip_year_pw_1234"
LOGIN = "payslip_year_user@test.com"


@tagged("-at_install", "post_install")
class TestMobilePayslipYearGrouping(HttpCase):
    """`year` on every payslip and the `years` index on /payslip/list.
    The year derives from `date_to`, the ordering field, so sections match list order."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.user = Users.create({
            "name": "Payslip Year User",
            "login": LOGIN,
            "password": PASSWORD,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Payslip Year User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })

    def _make_payslip(self, date_from, date_to, paid_date=None, employee=None):
        """A visible payslip with its state set directly, skipping the payroll compute."""
        employee = employee or self.employee
        payslip = self.env["hr.payslip"].sudo().create({
            "name": "Payslip %s" % date_to,
            "employee_id": employee.id,
            "date_from": date_from,
            "date_to": date_to,
        })
        self.env.cr.execute(
            "UPDATE hr_payslip SET state = 'validated' WHERE id = %s",
            [payslip.id])
        if paid_date:
            self.env.cr.execute(
                "UPDATE hr_payslip SET paid_date = %s WHERE id = %s",
                [paid_date, payslip.id])
        self.env.invalidate_all()
        return payslip

    def _token(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": LOGIN, "password": PASSWORD},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"]

    def _list(self, query="", token=None):
        resp = self.url_open(
            "/api/mobile/v1/payslip/list%s" % query,
            headers={"Authorization": "Bearer %s" % (token or self._token())})
        return resp.status_code, resp.json()

    def _data(self, query=""):
        status, body = self._list(query)
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"], body)
        return body["data"]

    def _row(self, data, payslip):
        return next(r for r in data["payslips"] if r["id"] == payslip.id)

    def test_year_follows_the_period_not_the_payment_date(self):
        """A December payslip paid in January belongs to December's year."""
        december = self._make_payslip("2025-12-01", "2025-12-31",
                                      paid_date="2026-01-05")
        row = self._row(self._data(), december)
        self.assertEqual(row["year"], 2025)
        self.assertEqual(row["payment_date"], "2026-01-05",
                         "the payment date is still reported, just not used "
                         "for grouping")

    def test_year_matches_the_field_the_list_is_ordered_by(self):
        """Sort key and group key must be the same field, or sections stop
        being contiguous."""
        self._make_payslip("2024-11-01", "2024-11-30", paid_date="2024-12-05")
        self._make_payslip("2025-12-01", "2025-12-31", paid_date="2026-01-05")
        self._make_payslip("2026-01-01", "2026-01-31", paid_date="2026-02-05")

        rows = self._data("?page_size=50")["payslips"]
        years = [r["year"] for r in rows]
        self.assertEqual(years, sorted(years, reverse=True),
                         "years must be non-increasing down the list, so each "
                         "section is one contiguous run: %s" % years)

    def test_sections_are_contiguous_runs(self):
        """No year may reappear after another year has started."""
        for month in (1, 6, 12):
            self._make_payslip("2025-%02d-01" % month, "2025-%02d-28" % month)
        for month in (3, 9):
            self._make_payslip("2026-%02d-01" % month, "2026-%02d-28" % month)

        years = [r["year"] for r in self._data("?page_size=50")["payslips"]]
        seen = []
        for year in years:
            if not seen or seen[-1] != year:
                self.assertNotIn(year, seen,
                                 "year %s reappears after the section closed: "
                                 "%s" % (year, years))
                seen.append(year)

    def test_same_period_orders_newest_created_first(self):
        """Equal `date_to` is tie-broken by `id desc`, newest created first."""
        first = self._make_payslip("2025-06-01", "2025-06-30")
        second = self._make_payslip("2025-06-01", "2025-06-30")

        ids = [r["id"] for r in self._data("?page_size=50")["payslips"]]
        self.assertLess(ids.index(second.id), ids.index(first.id),
                        "the most recently created payslip must come first")

    def test_latest_endpoint_picks_the_newest_created_of_a_tie(self):
        """The home card and the list must agree on which payslip is latest."""
        self._make_payslip("2025-06-01", "2025-06-30")
        newest = self._make_payslip("2025-06-01", "2025-06-30")

        resp = self.url_open(
            "/api/mobile/v1/payslip",
            headers={"Authorization": "Bearer %s" % self._token()})
        self.assertEqual(resp.json()["data"]["id"], newest.id)

    def test_ordering_is_stable_across_identical_requests(self):
        for _ in range(3):
            self._make_payslip("2025-06-01", "2025-06-30")
        first_call = [r["id"] for r in self._data("?page_size=50")["payslips"]]
        second_call = [r["id"] for r in self._data("?page_size=50")["payslips"]]
        self.assertEqual(first_call, second_call)

    def test_every_payslip_carries_a_year(self):
        self._make_payslip("2025-05-01", "2025-05-31")
        for row in self._data()["payslips"]:
            self.assertIn("year", row)
            self.assertIsInstance(row["year"], int)

    def test_latest_endpoint_also_carries_year(self):
        """`/payslip` reuses the same summary, so the field must be there
        too -- the home screen shows the same card."""
        self._make_payslip("2025-05-01", "2025-05-31")
        resp = self.url_open(
            "/api/mobile/v1/payslip",
            headers={"Authorization": "Bearer %s" % self._token()})
        data = resp.json()["data"]
        self.assertEqual(data["year"], 2025)

    def test_years_index_lists_every_year_newest_first(self):
        self._make_payslip("2024-01-01", "2024-01-31")
        self._make_payslip("2026-01-01", "2026-01-31")
        self._make_payslip("2025-01-01", "2025-01-31")

        years = self._data()["years"]
        self.assertEqual([row["year"] for row in years], [2026, 2025, 2024])

    def test_years_index_counts_the_whole_history_not_the_page(self):
        """A year index derived from one page would only describe that page,
        which is useless for a picker or for sizing sections ahead."""
        for month in range(1, 6):
            self._make_payslip("2025-%02d-01" % month, "2025-%02d-28" % month)

        data = self._data("?page_size=2")
        self.assertEqual(len(data["payslips"]), 2)
        self.assertEqual(
            next(r["count"] for r in data["years"] if r["year"] == 2025), 5)

    def test_years_index_is_empty_without_payslips(self):
        data = self._data()
        self.assertEqual(data["years"], [])
        self.assertEqual(data["payslips"], [])

    def test_year_filter_narrows_the_page(self):
        old = self._make_payslip("2024-03-01", "2024-03-31")
        new = self._make_payslip("2026-03-01", "2026-03-31")

        ids = [r["id"] for r in self._data("?year=2024")["payslips"]]
        self.assertIn(old.id, ids)
        self.assertNotIn(new.id, ids)

    def test_year_filter_is_echoed_back(self):
        self._make_payslip("2024-03-01", "2024-03-31")
        self.assertEqual(self._data("?year=2024")["year"], 2024)
        self.assertIsNone(self._data()["year"])

    def test_years_index_ignores_the_filter(self):
        """The picker must still list every selectable year while one of
        them is active."""
        self._make_payslip("2024-03-01", "2024-03-31")
        self._make_payslip("2026-03-01", "2026-03-31")

        years = [r["year"] for r in self._data("?year=2024")["years"]]
        self.assertEqual(years, [2026, 2024])

    def test_year_filter_paginates_within_the_year(self):
        for month in (1, 2, 3):
            self._make_payslip("2025-%02d-01" % month, "2025-%02d-28" % month)
        self._make_payslip("2026-01-01", "2026-01-31")

        data = self._data("?year=2025&page_size=2")
        self.assertEqual(data["pagination"]["total"], 3)
        self.assertEqual(data["pagination"]["total_pages"], 2)
        self.assertTrue(all(r["year"] == 2025 for r in data["payslips"]))

    def test_non_integer_year_is_a_400(self):
        status, body = self._list("?year=last")
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_year")

    def test_out_of_range_year_is_a_400_not_a_500(self):
        """`date(year, 1, 1)` raises outside 1-9999, which would escape as
        an HTML error page and break the JSON-only contract."""
        for value in ("0", "99999", "-2025"):
            status, body = self._list("?year=%s" % value)
            self.assertEqual(status, 400, "year=%s" % value)
            self.assertEqual(body["code"], "invalid_year")

    def test_empty_year_is_treated_as_absent(self):
        """`?year=` is what a client sends for "no filter"; it must not 400."""
        self._make_payslip("2025-03-01", "2025-03-31")
        data = self._data("?year=")
        self.assertIsNone(data["year"])
        self.assertTrue(data["payslips"])

    def test_year_with_no_payslips_returns_an_empty_page(self):
        self._make_payslip("2025-03-01", "2025-03-31")
        data = self._data("?year=1999")
        self.assertEqual(data["payslips"], [])
        self.assertEqual(data["pagination"]["total"], 0)
        self.assertTrue(data["years"], "the index still describes the history")

    def test_payment_date_replaces_distributed_date_on_every_surface(self):
        """`payment_date` replaces the old key identically on every payslip endpoint."""
        token = self._token()
        newest = self._make_payslip("2026-02-01", "2026-02-28",
                                    paid_date="2026-03-05")
        older = self._make_payslip("2026-01-01", "2026-01-31",
                                   paid_date="2026-02-05")

        def check(row, where):
            self.assertIn("payment_date", row, where)
            self.assertNotIn("distributed_date", row,
                             "%s still carries the old key" % where)

        resp = self.url_open("/api/mobile/v1/payslip",
                             headers={"Authorization": "Bearer %s" % token})
        data = resp.json()["data"]
        check(data, "/payslip main object")
        self.assertEqual(data["id"], newest.id)
        self.assertEqual(data["payment_date"], "2026-03-05")
        self.assertTrue(data["history"], "sanity: there is a history to check")
        for entry in data["history"]:
            check(entry, "/payslip history entry")

        check(self._row(self._data(), older), "/payslip/list row")

        resp = self.url_open("/api/mobile/v1/payslip/%s" % older.id,
                             headers={"Authorization": "Bearer %s" % token})
        check(resp.json()["data"], "/payslip/<id>")
        self.assertEqual(resp.json()["data"]["payment_date"], "2026-02-05")

    def test_payment_date_is_that_payslips_own_not_a_neighbours(self):
        """Each entry reports its own payslip's payment date; unpaid slips report null."""
        unpaid = self._make_payslip("2026-05-01", "2026-05-31")
        paid = self._make_payslip("2026-04-01", "2026-04-30",
                                  paid_date="2026-05-06")
        token = self._token()
        resp = self.url_open("/api/mobile/v1/payslip",
                             headers={"Authorization": "Bearer %s" % token})
        data = resp.json()["data"]
        self.assertEqual(data["id"], unpaid.id, "the newest is the unpaid one")
        self.assertIsNone(data["payment_date"],
                          "an unpaid payslip reports null, not a neighbour's date")
        paid_row = next(h for h in data["history"] if h["id"] == paid.id)
        self.assertEqual(paid_row["payment_date"], "2026-05-06")

    def test_payment_date_is_reported_even_when_the_state_is_not_paid(self):
        """`paid_date` is reported even while the slip is still `validated`.
        Odoo's payment-report wizard stamps it before the state becomes `paid`."""
        slip = self._make_payslip("2026-06-01", "2026-06-30",
                                  paid_date="2026-07-03")
        self.assertEqual(slip.state, "validated", "sanity: not marked paid")
        row = self._row(self._data(), slip)
        self.assertEqual(row["payment_date"], "2026-07-03")
