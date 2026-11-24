import json
from datetime import date

from odoo.tests import HttpCase, tagged

LOGIN = "expense_filter_user@test.com"
PASSWORD = "expense_filter_pw_1234"
OTHER_LOGIN = "expense_filter_other@test.com"


@tagged("post_install", "-at_install")
class TestExpenseFiltersApi(HttpCase):
    """Source-scoped filter routes and grouped listing.
    Fixture: Sep 3 claims, Aug 2, Jul 1, Dec 2025 1 (Travel only), across Meals and Travel."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        Product = cls.env["product.product"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        groups = [(4, mobile_group.id), (4, internal_group.id)]
        company = cls.env.ref("base.main_company")

        cls.meals = Product.create({
            "name": "Filter Meals", "type": "service", "can_be_expensed": True})
        cls.travel = Product.create({
            "name": "Filter Travel", "type": "service", "can_be_expensed": True})

        cls.user = Users.create({
            "name": "Expense Filter User", "login": LOGIN,
            "password": PASSWORD, "group_ids": groups})
        cls.employee = Employee.create({
            "name": "Expense Filter User", "company_id": company.id,
            "user_id": cls.user.id})

        cls.other_user = Users.create({
            "name": "Expense Filter Other", "login": OTHER_LOGIN,
            "password": PASSWORD, "group_ids": groups})
        cls.other_employee = Employee.create({
            "name": "Expense Filter Other", "company_id": company.id,
            "user_id": cls.other_user.id})

        cls.rows = [
            ("sep-a", date(2026, 9, 20), cls.meals),
            ("sep-b", date(2026, 9, 10), cls.meals),
            ("sep-c", date(2026, 9, 5), cls.travel),
            ("aug-a", date(2026, 8, 15), cls.meals),
            ("aug-b", date(2026, 8, 2), cls.travel),
            ("jul-a", date(2026, 7, 9), cls.meals),
            ("dec-a", date(2025, 12, 3), cls.travel),
        ]
        # Distinct amounts so a wrong total cannot coincide with a right one.
        cls.amounts = {
            "sep-a": 100.0, "sep-b": 20.0, "sep-c": 3.0,
            "aug-a": 400.0, "aug-b": 50.0,
            "jul-a": 7.0,
            "dec-a": 900.0,
        }
        # `state` is a stored computed field mapped from `approval_state`, so write the approval field.
        cls.approval = {
            "sep-a": "submitted", "sep-b": "approved", "sep-c": "refused",
            "aug-a": "approved", "aug-b": None,
            "jul-a": None, "dec-a": "refused",
        }
        for name, on, category in cls.rows:
            cls.env["hr.expense"].sudo().create({
                "name": name,
                "employee_id": cls.employee.id,
                "product_id": category.id,
                "quantity": 1,
                "total_amount_currency": cls.amounts[name],
                "date": on,
                "payment_mode": "own_account",
            })
        for expense in cls.env["hr.expense"].sudo().search(
                [("employee_id", "=", cls.employee.id)]):
            approval = cls.approval.get(expense.name)
            if approval:
                expense.write({"approval_state": approval})

    def _token(self, login=LOGIN):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": login, "password": PASSWORD},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"]

    def _get(self, path, token=None):
        resp = self.url_open(
            path, headers={"Authorization": "Bearer %s" % (token or self._token())})
        return resp.status_code, resp.json()

    def _apply(self, option, payload, token=None, source="expense"):
        resp = self.url_open(
            "/api/mobile/v1/filters/apply?source=%s&option=%s" % (source, option),
            headers={"Authorization": "Bearer %s" % (token or self._token()),
                     "Content-Type": "application/json"},
            data=json.dumps(payload if payload is not None else {}),
            method="POST",
        )
        return resp.status_code, resp.json()

    def _groups(self, page=1, limit=50, token=None):
        status, body = self._get(
            "/api/mobile/v1/expense?page=%s&limit=%s" % (page, limit), token)
        self.assertEqual(status, 200, body)
        return body["data"]["groups"]

    @staticmethod
    def _shape(groups):
        """`[("September 2026", ["sep-a", "sep-b"]), ...]` -- readable diffs."""
        return [(g["timeline"], [e["title"] for e in g["expenses"]])
                for g in groups]

    def test_options_menu_lists_the_sources_filters(self):
        status, body = self._get("/api/mobile/v1/filters/options?source=expense")
        self.assertEqual(status, 200, body)
        data = body["data"]
        self.assertEqual(data["source"], "expense")
        self.assertEqual([o["option"] for o in data["options"]],
                         ["category", "status", "month"])

    def test_menu_entries_carry_a_ready_made_url(self):
        """The app follows links instead of composing URLs from constants it
        would have to keep in step with the server."""
        _status, body = self._get("/api/mobile/v1/filters/options?source=expense")
        for option in body["data"]["options"]:
            self.assertEqual(
                option["url"],
                "/api/mobile/v1/filters?source=expense&option=%s" % option["option"])
            status, values = self._get(option["url"])
            self.assertEqual(status, 200, values)
            self.assertEqual(values["data"]["option"], option["option"])

    def test_date_range_is_appliable_but_not_a_menu_entry(self):
        """It is reached from the month panel, not from the top-level menu."""
        _status, body = self._get("/api/mobile/v1/filters/options?source=expense")
        self.assertNotIn("date_range", [o["option"] for o in body["data"]["options"]])
        status, _values = self._get(
            "/api/mobile/v1/filters?source=expense&option=date_range")
        self.assertEqual(status, 404)
        status, _applied = self._apply("date_range", {
            "from_date": "2026-09-01", "to_date": "2026-09-30"})
        self.assertEqual(status, 200)

    def test_category_values_are_a_flat_id_label_list(self):
        status, body = self._get(
            "/api/mobile/v1/filters?source=expense&option=category")
        self.assertEqual(status, 200, body)
        data = body["data"]
        self.assertEqual(data["option"], "category")
        self.assertEqual(data["selection"], "multi")
        labels = [i["label"] for i in data["items"]]
        self.assertIn("Filter Meals", labels)
        self.assertIn("Filter Travel", labels)
        for item in data["items"]:
            self.assertEqual(sorted(item.keys()), ["id", "label"])

    def test_month_without_bucket_returns_buckets_newest_year_first(self):
        status, body = self._get(
            "/api/mobile/v1/filters?source=expense&option=month")
        self.assertEqual(status, 200, body)
        data = body["data"]
        self.assertEqual(data["level"], "bucket")
        self.assertEqual([b["key"] for b in data["buckets"]],
                         ["recent", "2026", "2025"])
        self.assertTrue(data["custom_range_available"])

    def test_recent_bucket_spans_year_boundaries(self):
        """"Recent" is N months with data, crossing year boundaries."""
        status, body = self._get(
            "/api/mobile/v1/filters?source=expense&option=month&bucket=recent")
        self.assertEqual(status, 200, body)
        ids = [i["id"] for i in body["data"]["items"]]
        self.assertEqual(ids, ["2026-09", "2026-08", "2026-07", "2025-12"])
        self.assertEqual(body["data"]["items"][0]["label"], "Sep 2026")

    def test_year_bucket_is_limited_to_that_year_and_to_months_with_data(self):
        status, body = self._get(
            "/api/mobile/v1/filters?source=expense&option=month&bucket=2026")
        self.assertEqual(status, 200, body)
        self.assertEqual([i["id"] for i in body["data"]["items"]],
                         ["2026-09", "2026-08", "2026-07"])

    def test_month_values_never_include_another_employees_months(self):
        self.env["hr.expense"].sudo().create({
            "name": "not mine", "employee_id": self.other_employee.id,
            "product_id": self.meals.id, "quantity": 1,
            "total_amount_currency": 10.0, "date": date(2024, 3, 4),
            "payment_mode": "own_account"})
        _status, body = self._get(
            "/api/mobile/v1/filters?source=expense&option=month")
        self.assertNotIn("2024", [b["key"] for b in body["data"]["buckets"]])

    def test_unknown_option_is_rejected(self):
        status, body = self._get(
            "/api/mobile/v1/filters?source=expense&option=colour")
        self.assertEqual(status, 404, body)
        self.assertEqual(body["code"], "unknown_option")

    def test_unknown_source_is_rejected(self):
        # A source that is genuinely not registered.
        status, body = self._get(
            "/api/mobile/v1/filters?source=invoice&option=month")
        self.assertEqual(status, 404, body)
        self.assertEqual(body["code"], "unknown_source")

    def test_missing_source_and_option_are_rejected(self):
        status, body = self._get("/api/mobile/v1/filters?option=month")
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "missing_source")
        status, body = self._get("/api/mobile/v1/filters?source=expense")
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "missing_option")

    def test_bad_bucket_is_rejected(self):
        status, body = self._get(
            "/api/mobile/v1/filters?source=expense&option=month&bucket=soon")
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "invalid_bucket")

    def test_apply_routes_to_the_right_handler_per_option(self):
        """The same URL, three different bodies, three different filters."""
        _s, body = self._apply("category", {"category_ids": [self.meals.id]})
        self.assertEqual(body["data"]["active"]["category_ids"], [self.meals.id])
        _s, body = self._apply("month", {"month_ids": ["2026-07"]})
        self.assertEqual(body["data"]["active"]["month_ids"], ["2026-07"])
        self.assertEqual(body["data"]["active"]["category_ids"], [self.meals.id],
                         "applying one option must not disturb an unrelated one")
        _s, body = self._apply("date_range", {
            "from_date": "2026-08-01", "to_date": "2026-08-31"})
        self.assertEqual(body["data"]["active"]["date_range"],
                         {"from_date": "2026-08-01", "to_date": "2026-08-31"})

    def test_apply_rejects_an_unknown_option(self):
        status, body = self._apply("colour", {"values": []})
        self.assertEqual(status, 404, body)
        self.assertEqual(body["code"], "unknown_option")

    def test_category_clears_on_null_missing_and_empty_list(self):
        for payload in ({"category_ids": None}, {}, {"category_ids": []}):
            self._apply("category", {"category_ids": [self.meals.id]})
            status, body = self._apply("category", payload)
            self.assertEqual(status, 200, body)
            self.assertTrue(body["data"]["cleared"], payload)
            self.assertEqual(body["data"]["active"]["category_ids"], [], payload)

    def test_month_clears_on_null_missing_and_empty_list(self):
        for payload in ({"month_ids": None}, {}, {"month_ids": []}):
            self._apply("month", {"month_ids": ["2026-09"]})
            status, body = self._apply("month", payload)
            self.assertEqual(status, 200, body)
            self.assertTrue(body["data"]["cleared"], payload)
            self.assertEqual(body["data"]["active"]["month_ids"], [], payload)

    def test_date_range_clears_on_both_null_and_on_empty_body(self):
        for payload in ({"from_date": None, "to_date": None}, {}):
            self._apply("date_range", {"from_date": "2026-09-01",
                                       "to_date": "2026-09-30"})
            status, body = self._apply("date_range", payload)
            self.assertEqual(status, 200, body)
            self.assertTrue(body["data"]["cleared"], payload)
            self.assertIsNone(body["data"]["active"]["date_range"], payload)

    def test_a_non_object_body_clears_rather_than_erroring(self):
        """A non-object body is normalised to {} and clears filters rather than returning 400."""
        self._apply("month", {"month_ids": ["2026-09"]})
        resp = self.url_open(
            "/api/mobile/v1/filters/apply?source=expense&option=month",
            headers={"Authorization": "Bearer %s" % self._token(),
                     "Content-Type": "application/json"},
            data="[1, 2]", method="POST")
        body = resp.json()
        self.assertEqual(resp.status_code, 200, body)
        self.assertTrue(body["data"]["cleared"])
        self.assertEqual(body["data"]["active"]["month_ids"], [])

    def test_applying_months_clears_an_active_date_range(self):
        self._apply("date_range", {"from_date": "2026-09-01",
                                   "to_date": "2026-09-30"})
        _status, body = self._apply("month", {"month_ids": ["2026-07"]})
        self.assertEqual(body["data"]["active"]["month_ids"], ["2026-07"])
        self.assertIsNone(body["data"]["active"]["date_range"],
                          "the date range must have been cleared")

    def test_applying_a_date_range_clears_selected_months(self):
        self._apply("month", {"month_ids": ["2026-07", "2026-08"]})
        _status, body = self._apply("date_range", {
            "from_date": "2026-09-01", "to_date": "2026-09-30"})
        self.assertEqual(body["data"]["active"]["month_ids"], [])
        self.assertEqual(body["data"]["active"]["date_range"],
                         {"from_date": "2026-09-01", "to_date": "2026-09-30"})

    def test_clearing_months_does_not_resurrect_a_date_range(self):
        self._apply("date_range", {"from_date": "2026-09-01",
                                   "to_date": "2026-09-30"})
        self._apply("month", {"month_ids": ["2026-07"]})
        _status, body = self._apply("month", {"month_ids": None})
        self.assertEqual(body["data"]["active"]["month_ids"], [])
        self.assertIsNone(body["data"]["active"]["date_range"])

    def test_partial_date_range_is_a_validation_error(self):
        """Half a date range is rejected, not read as open-ended."""
        for payload in ({"from_date": "2026-09-01"},
                        {"to_date": "2026-09-30"},
                        {"from_date": "2026-09-01", "to_date": None}):
            status, body = self._apply("date_range", payload)
            self.assertEqual(status, 400, payload)
            self.assertEqual(body["code"], "invalid_date_range", payload)

    def test_reversed_and_malformed_date_ranges_are_rejected(self):
        status, body = self._apply("date_range", {
            "from_date": "2026-09-30", "to_date": "2026-09-01"})
        self.assertEqual(status, 400, body)
        status, body = self._apply("date_range", {
            "from_date": "yesterday", "to_date": "2026-09-01"})
        self.assertEqual(status, 400, body)

    def test_malformed_month_ids_are_rejected(self):
        for bad in (["2026-13"], ["Sep 2026"], "2026-09", [2026]):
            status, body = self._apply("month", {"month_ids": bad})
            self.assertEqual(status, 400, bad)
            self.assertEqual(body["code"], "invalid_month_ids", bad)

    def test_malformed_category_ids_are_rejected(self):
        status, body = self._apply("category", {"category_ids": "all"})
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "invalid_category_ids")

    def test_one_users_filter_does_not_reach_another(self):
        self._apply("month", {"month_ids": ["2026-07"]})
        other = self._token(OTHER_LOGIN)
        _status, body = self._get(
            "/api/mobile/v1/filters/options?source=expense", other)
        self.assertEqual(body["data"]["active"]["month_ids"], [])

    def test_branch_1_no_filters_groups_every_month_newest_first(self):
        self.assertEqual(self._shape(self._groups()), [
            ("September 2026", ["sep-a", "sep-b", "sep-c"]),
            ("August 2026", ["aug-a", "aug-b"]),
            ("July 2026", ["jul-a"]),
            ("December 2025", ["dec-a"]),
        ])

    def test_branch_2_categories_only_keeps_all_months_but_omits_empty_ones(self):
        self._apply("category", {"category_ids": [self.meals.id]})
        self.assertEqual(self._shape(self._groups()), [
            ("September 2026", ["sep-a", "sep-b"]),
            ("August 2026", ["aug-a"]),
            ("July 2026", ["jul-a"]),
        ], "December has no Meals claim, so it must not appear at all")

    def test_branch_3_months_only_returns_just_those_months(self):
        self._apply("month", {"month_ids": ["2026-09", "2026-07"]})
        self.assertEqual(self._shape(self._groups()), [
            ("September 2026", ["sep-a", "sep-b", "sep-c"]),
            ("July 2026", ["jul-a"]),
        ])

    def test_branch_4_months_and_categories_intersect(self):
        self._apply("month", {"month_ids": ["2026-09", "2026-08"]})
        self._apply("category", {"category_ids": [self.travel.id]})
        self.assertEqual(self._shape(self._groups()), [
            ("September 2026", ["sep-c"]),
            ("August 2026", ["aug-b"]),
        ])

    def test_branch_5_date_range_is_one_flat_group_headed_by_the_range(self):
        self._apply("date_range", {"from_date": "2026-07-01",
                                   "to_date": "2026-09-12"})
        groups = self._groups()
        self.assertEqual(len(groups), 1, "a range must not be re-cut by month")
        self.assertEqual(groups[0]["timeline"], "Jul 1 - Sep 12, 2026")
        self.assertEqual([e["title"] for e in groups[0]["expenses"]],
                         ["sep-b", "sep-c", "aug-a", "aug-b", "jul-a"])

    def test_branch_6_date_range_and_categories(self):
        self._apply("date_range", {"from_date": "2026-07-01",
                                   "to_date": "2026-09-12"})
        self._apply("category", {"category_ids": [self.meals.id]})
        groups = self._groups()
        self.assertEqual(len(groups), 1)
        self.assertEqual(groups[0]["timeline"], "Jul 1 - Sep 12, 2026")
        self.assertEqual([e["title"] for e in groups[0]["expenses"]],
                         ["sep-b", "aug-a", "jul-a"])

    def test_status_values_are_a_flat_id_label_list(self):
        status, body = self._get(
            "/api/mobile/v1/filters?source=expense&option=status")
        self.assertEqual(status, 200, body)
        data = body["data"]
        self.assertEqual(data["option"], "status")
        self.assertEqual(data["selection"], "multi")
        self.assertEqual([i["id"] for i in data["items"]],
                         ["draft", "pending", "approved", "paid", "refused"])
        for item in data["items"]:
            self.assertEqual(sorted(item.keys()), ["id", "label"])

    def test_status_appears_in_the_filter_menu(self):
        _status, body = self._get("/api/mobile/v1/filters/options?source=expense")
        options = [o["option"] for o in body["data"]["options"]]
        self.assertIn("status", options)
        entry = next(o for o in body["data"]["options"] if o["option"] == "status")
        self.assertEqual(entry["selection"], "multi")
        status, values = self._get(entry["url"])
        self.assertEqual(status, 200, values)

    def test_status_ids_are_the_ones_the_rows_show(self):
        """A client must be able to pass back exactly what it rendered."""
        _s, body = self._get("/api/mobile/v1/filters?source=expense&option=status")
        offered = {i["id"] for i in body["data"]["items"]}
        shown = {e["status"] for g in self._groups() for e in g["expenses"]}
        self.assertTrue(shown, "fixture produced no rows")
        self.assertTrue(shown <= offered,
                        "rows show statuses the filter cannot offer: %s"
                        % (shown - offered))

    def test_apply_status_narrows_the_listing(self):
        self._apply("status", {"status_ids": ["refused"]})
        self.assertEqual(self._shape(self._groups()), [
            ("September 2026", ["sep-c"]),
            ("December 2025", ["dec-a"]),
        ])

    def test_status_covers_every_odoo_state_behind_it(self):
        """`approved` must also catch `posted`, and `paid` catch `in_payment`."""
        from ..filter_sources import ExpenseFilterSource

        source = ExpenseFilterSource(self.user)
        # Assert the domain: posted/in_payment need account moves that fixtures can't cheaply reach.
        for status, expected in (("approved", ["approved", "posted"]),
                                 ("paid", ["in_payment", "paid"]),
                                 ("pending", ["submitted"])):
            leaves = source.domain_from_state({"status": [status]})
            state_leaf = next(l for l in leaves
                              if isinstance(l, tuple) and l[0] == "state")
            self.assertEqual(sorted(state_leaf[2]), sorted(expected),
                             "status %r expanded to %s" % (status, state_leaf[2]))
        self._apply("status", {"status_ids": ["approved"]})
        self.assertEqual(self._titles(self._search("")), ["sep-b", "aug-a"])

    def test_status_multi_select_is_a_union(self):
        self._apply("status", {"status_ids": ["refused", "pending"]})
        titles = [e["title"] for g in self._groups() for e in g["expenses"]]
        self.assertEqual(titles, ["sep-a", "sep-c", "dec-a"])

    def test_status_clears_on_null_missing_and_empty_list(self):
        for payload in ({"status_ids": None}, {}, {"status_ids": []}):
            self._apply("status", {"status_ids": ["refused"]})
            status, body = self._apply("status", payload)
            self.assertEqual(status, 200, body)
            self.assertTrue(body["data"]["cleared"], payload)
            self.assertEqual(body["data"]["active"]["status_ids"], [], payload)

    def test_malformed_status_ids_are_rejected(self):
        for bad in (["nope"], "approved", [1], ["Approved"]):
            status, body = self._apply("status", {"status_ids": bad})
            self.assertEqual(status, 400, bad)
            self.assertEqual(body["code"], "invalid_status_ids", bad)

    def test_status_ands_with_category(self):
        self._apply("status", {"status_ids": ["approved"]})
        self._apply("category", {"category_ids": [self.meals.id]})
        self.assertEqual(self._shape(self._groups()), [
            ("September 2026", ["sep-b"]),
            ("August 2026", ["aug-a"]),
        ], "sep-c is refused, aug-b is Travel -- neither qualifies")

    def test_status_ands_with_a_date_range(self):
        """The range branch returns early; status must still apply there."""
        self._apply("status", {"status_ids": ["refused"]})
        self._apply("date_range", {"from_date": "2026-01-01",
                                   "to_date": "2026-12-31"})
        groups = self._groups()
        self.assertEqual(len(groups), 1)
        self.assertEqual([e["title"] for e in groups[0]["expenses"]], ["sep-c"],
                         "dec-a is refused but outside the range")

    def test_status_ands_with_months(self):
        self._apply("status", {"status_ids": ["refused"]})
        self._apply("month", {"month_ids": ["2025-12"]})
        self.assertEqual(self._shape(self._groups()),
                         [("December 2025", ["dec-a"])])

    def test_status_ands_with_search(self):
        self._apply("status", {"status_ids": ["refused"]})
        self.assertEqual(self._titles(self._search("sep-")), ["sep-c"])

    def test_status_narrows_the_timeline_totals(self):
        self._apply("status", {"status_ids": ["refused"]})
        groups = {g["timeline"]: g for g in self._groups()}
        self.assertAlmostEqual(groups["September 2026"]["total_amount"], 3.0, 2,
                               "only sep-c (3.00) is refused in September")

    def _search(self, term, page=1, limit=50):
        status, body = self._get(
            "/api/mobile/v1/expense?page=%s&limit=%s&search=%s"
            % (page, limit, term))
        self.assertEqual(status, 200, body)
        return body["data"]

    @staticmethod
    def _titles(data):
        return [e["title"] for g in data["groups"] for e in g["expenses"]]

    def test_search_matches_the_expense_title(self):
        self.assertEqual(self._titles(self._search("sep-")),
                         ["sep-a", "sep-b", "sep-c"])

    def test_search_matches_the_category_shown_on_the_row(self):
        """Search matches the category shown on the row, not only the title."""
        self.assertEqual(self._titles(self._search("Filter Meals")),
                         ["sep-a", "sep-b", "aug-a", "jul-a"])

    def test_search_matches_an_amount_as_rendered(self):
        """`aug-a` is the only 400.00 claim."""
        self.assertEqual(self._titles(self._search("400")), ["aug-a"])

    def test_search_is_case_insensitive(self):
        self.assertEqual(self._titles(self._search("SEP-A")), ["sep-a"])

    def test_search_that_matches_nothing_returns_no_groups(self):
        data = self._search("zzz-nothing-matches")
        self.assertEqual(data["groups"], [])
        self.assertEqual(data["pagination"]["total"], 0)

    def test_search_narrows_within_an_active_category_filter(self):
        """Search ANDs with the stored filters rather than replacing them."""
        self._apply("category", {"category_ids": [self.travel.id]})
        self.assertEqual(self._titles(self._search("sep-")), ["sep-c"])

    def test_search_narrows_within_an_active_month_filter(self):
        """The month filter builds an OR-of-windows domain; search has to AND
        with the whole of it, not with its last branch."""
        self._apply("month", {"month_ids": ["2026-09", "2026-07"]})
        self.assertEqual(self._titles(self._search("Filter Meals")),
                         ["sep-a", "sep-b", "jul-a"],
                         "aug-a is Meals but August is not a selected month")

    def test_search_narrows_within_an_active_date_range(self):
        self._apply("date_range", {"from_date": "2026-07-01",
                                   "to_date": "2026-09-12"})
        data = self._search("Filter Meals")
        self.assertEqual(len(data["groups"]), 1, "still one range group")
        self.assertEqual(data["groups"][0]["timeline"], "Jul 1 - Sep 12, 2026")
        self.assertEqual(self._titles(data), ["sep-b", "aug-a", "jul-a"])

    def test_search_applies_to_rows_not_to_groups(self):
        """A group is kept only if one of its own expenses matched the search."""
        timelines = [g["timeline"] for g in self._search("Filter Meals")["groups"]]
        self.assertEqual(timelines,
                         ["September 2026", "August 2026", "July 2026"])
        self.assertNotIn("December 2025", timelines)

    def test_search_is_paginated_by_matching_rows(self):
        """Pagination counts MATCHES, not the unfiltered set."""
        data = self._search("Filter Meals", page=1, limit=2)
        self.assertEqual(data["pagination"]["total"], 4)
        self.assertEqual(self._titles(data), ["sep-a", "sep-b"])
        self.assertTrue(data["pagination"]["has_next"])
        data = self._search("Filter Meals", page=2, limit=2)
        self.assertEqual(self._titles(data), ["aug-a", "jul-a"])
        self.assertFalse(data["pagination"]["has_next"])

    def test_search_totals_cover_the_matches_only(self):
        """The per-timeline total must reflect the search, or the header
        would contradict the rows under it."""
        groups = {g["timeline"]: g for g in self._search("Filter Meals")["groups"]}
        self.assertAlmostEqual(groups["September 2026"]["total_amount"], 120.0, 2,
                               "sep-c is Travel and must not be counted")
        self.assertAlmostEqual(groups["August 2026"]["total_amount"], 400.0, 2)

    def test_search_does_not_leak_another_employees_expenses(self):
        self.env["hr.expense"].sudo().create({
            "name": "sep-a", "employee_id": self.other_employee.id,
            "product_id": self.meals.id, "quantity": 1,
            "total_amount_currency": 10.0, "date": date(2026, 9, 20),
            "payment_mode": "own_account"})
        self.assertEqual(len(self._titles(self._search("sep-a"))), 1,
                         "the other employee's identically-named claim leaked")

    def test_each_group_carries_its_timeline_total(self):
        groups = {g["timeline"]: g for g in self._groups()}
        self.assertAlmostEqual(groups["September 2026"]["total_amount"], 123.0, 2)
        self.assertAlmostEqual(groups["August 2026"]["total_amount"], 450.0, 2)
        self.assertAlmostEqual(groups["July 2026"]["total_amount"], 7.0, 2)
        self.assertAlmostEqual(groups["December 2025"]["total_amount"], 900.0, 2)
        for group in groups.values():
            self.assertIn("total_amount_display", group)
            self.assertIn("currency", group)

    def test_the_total_is_the_whole_month_not_just_this_page(self):
        """A month split across pages shows the whole-month total on every page."""
        page1 = self._groups(page=1, limit=2)
        page2 = self._groups(page=2, limit=2)
        self.assertEqual(page1[0]["timeline"], "September 2026")
        self.assertEqual(page2[0]["timeline"], "September 2026")
        self.assertAlmostEqual(page1[0]["total_amount"], 123.0, 2)
        self.assertAlmostEqual(page2[0]["total_amount"], 123.0, 2,
                               "the same heading must carry the same total")
        self.assertAlmostEqual(
            sum(e["amount"] for e in page1[0]["expenses"]), 120.0, 2,
            "sanity: the PAGE really does hold only part of the month")

    def test_the_total_respects_the_active_filters(self):
        """A category filter changes the total, not just the rows."""
        self._apply("category", {"category_ids": [self.meals.id]})
        groups = {g["timeline"]: g for g in self._groups()}
        self.assertAlmostEqual(groups["September 2026"]["total_amount"], 120.0, 2,
                               "sep-c is Travel and must be excluded")
        self.assertAlmostEqual(groups["August 2026"]["total_amount"], 400.0, 2)

    def test_a_date_range_group_totals_the_whole_range(self):
        self._apply("date_range", {"from_date": "2026-07-01",
                                   "to_date": "2026-09-12"})
        groups = self._groups(page=1, limit=2)
        self.assertEqual(len(groups), 1)
        # sep-b 20 + sep-c 3 + aug-a 400 + aug-b 50 + jul-a 7 = 480
        self.assertAlmostEqual(groups[0]["total_amount"], 480.0, 2)
        self.assertAlmostEqual(
            sum(e["amount"] for e in groups[0]["expenses"]), 23.0, 2,
            "sanity: limit=2 shows only part of the range")

    def test_a_page_can_end_mid_month(self):
        """limit=2 over a three-claim September: the month is split, and the
        same heading legitimately appears on both pages."""
        self.assertEqual(self._shape(self._groups(page=1, limit=2)), [
            ("September 2026", ["sep-a", "sep-b"]),
        ])
        self.assertEqual(self._shape(self._groups(page=2, limit=2)), [
            ("September 2026", ["sep-c"]),
            ("August 2026", ["aug-a"]),
        ], "page 2 starts mid-September and runs into August")

    def test_pagination_counts_expenses_not_groups(self):
        status, body = self._get("/api/mobile/v1/expense?page=1&limit=2")
        self.assertEqual(status, 200, body)
        pagination = body["data"]["pagination"]
        self.assertEqual(pagination["total"], len(self.rows),
                         "total counts expenses, not month buckets")
        self.assertEqual(sum(len(g["expenses"]) for g in body["data"]["groups"]), 2)
        self.assertTrue(pagination["has_next"])

    def test_the_redundant_items_key_is_gone(self):
        """`groups` is the only list of expenses in the response."""
        status, body = self._get("/api/mobile/v1/expense?page=1&limit=3")
        self.assertEqual(status, 200, body)
        self.assertNotIn("items", body["data"])
        self.assertEqual(sorted(body["data"].keys()),
                         ["filters", "groups", "pagination"])

    def test_groups_hold_exactly_the_requested_page(self):
        """Flattened groups reproduce exactly the requested page, in order."""
        expected = ["sep-a", "sep-b", "sep-c", "aug-a", "aug-b", "jul-a", "dec-a"]
        for limit in (1, 2, 3, 7, 20):
            seen = []
            page = 1
            while True:
                status, body = self._get(
                    "/api/mobile/v1/expense?page=%s&limit=%s" % (page, limit))
                self.assertEqual(status, 200, body)
                data = body["data"]
                flat = [e["title"] for g in data["groups"] for e in g["expenses"]]
                self.assertLessEqual(
                    len(flat), limit,
                    "limit=%s page=%s returned %s rows" % (limit, page, len(flat)))
                seen += flat
                if not data["pagination"]["has_next"]:
                    break
                page += 1
                self.assertLess(page, 50, "runaway pagination")
            self.assertEqual(
                seen, expected,
                "limit=%s did not walk the full set in order" % limit)

    def test_a_full_page_is_exactly_limit_rows_across_its_groups(self):
        """A page that spans a month boundary is still `limit` rows total --
        the split adds a group, not a row."""
        status, body = self._get("/api/mobile/v1/expense?page=2&limit=2")
        self.assertEqual(status, 200, body)
        groups = body["data"]["groups"]
        self.assertEqual(len(groups), 2, "this page straddles Sep/Aug")
        self.assertEqual(sum(len(g["expenses"]) for g in groups), 2)

    def test_an_empty_page_has_no_groups(self):
        self._apply("month", {"month_ids": ["2026-07"]})
        self.assertEqual(self._groups(page=5, limit=20), [])
