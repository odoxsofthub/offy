import json
from datetime import date, timedelta

from odoo.tests import HttpCase, tagged

PASSWORD = "tp_filter_pw_1234"
LOGIN = "tp_filter_user@test.com"

# The main view for most timeoff cases; a later section drives BOTH views.
VIEW = "upcoming"


def _monday(offset_weeks):
    today = date.today()
    monday = today - timedelta(days=today.weekday())
    return monday + timedelta(weeks=offset_weeks)


class DispatchMixin:
    """Shared helpers -- the dispatch routes are the same three for every
    source, which is the point of the design being tested."""

    def _token(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": LOGIN, "password": PASSWORD},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"]

    def _get(self, path):
        resp = self.url_open(
            path, headers={"Authorization": "Bearer %s" % self._token()})
        return resp.status_code, resp.json()

    def _apply(self, source, option, payload, view=None):
        suffix = "&view=%s" % view if view else ""
        resp = self.url_open(
            "/api/mobile/v1/filters/apply?source=%s%s&option=%s"
            % (source, suffix, option),
            headers={"Authorization": "Bearer %s" % self._token(),
                     "Content-Type": "application/json"},
            data=json.dumps(payload), method="POST")
        return resp.status_code, resp.json()

    def _active(self, source, view=None):
        suffix = "&view=%s" % view if view else ""
        status, body = self._get(
            "/api/mobile/v1/filters/options?source=%s%s" % (source, suffix))
        self.assertEqual(status, 200, body)
        return body["data"]["active"]


@tagged("post_install", "-at_install")
class TestTimeoffFiltersApi(DispatchMixin, HttpCase):
    """`source=timeoff` on the existing dispatch, and the two listings.
    Fixture: past and future leaves of two types, so both upcoming and history have rows."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        LeaveType = cls.env["hr.leave.type"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.user = Users.create({
            "name": "TP Filter User", "login": LOGIN, "password": PASSWORD,
            "tz": "UTC",
            "group_ids": [(4, mobile_group.id), (4, internal.id)]})
        cls.employee = Employee.create({
            "name": "TP Filter User", "company_id": company.id,
            "user_id": cls.user.id})

        cls.annual = LeaveType.create({
            "name": "TP Annual Leave", "requires_allocation": False,
            "request_unit": "day", "leave_validation_type": "hr"})
        cls.sick = LeaveType.create({
            "name": "TP Sick Leave", "requires_allocation": False,
            "request_unit": "day", "leave_validation_type": "hr"})

        # `private_name` is the row's `name` when set -- the "reason".
        cls.past_annual = cls._leave(cls, cls.annual, _monday(-8), "validate")
        cls.past_annual.sudo().private_name = "Grandmother funeral"
        cls.past_sick = cls._leave(cls, cls.sick, _monday(-6), "refuse")
        cls.future_annual = cls._leave(cls, cls.annual, _monday(4), "validate")
        cls.future_sick = cls._leave(cls, cls.sick, _monday(6), None)
        cls.future_annual.sudo().private_name = "Cousin wedding in Kerala"

    def _leave(self, leave_type, day, state):
        leave = self.env["hr.leave"].sudo().create({
            "employee_id": self.employee.id,
            "holiday_status_id": leave_type.id,
            "request_date_from": day,
            "request_date_to": day,
        })
        if state:
            leave.write({"state": state})
        return leave

    def _list(self, which, search=None):
        suffix = "&search=%s" % search if search else ""
        status, body = self._get(
            "/api/mobile/v1/timeoff/%s?page=1&page_size=50%s" % (which, suffix))
        self.assertEqual(status, 200, body)
        return body["data"]

    def _ids(self, which, search=None):
        return {row["id"]
                for group in self._list(which, search)["leaves"]
                for row in group["leaves"]}

    def _clear_all(self):
        for view in ("upcoming", "history"):
            for option in ("month", "status", "leave_type", "date_range"):
                self._apply("timeoff", option, {}, view=view)

    def setUp(self):
        super().setUp()
        self.addCleanup(self._clear_all)

    def test_options_menu_lists_the_timeoff_filters(self):
        status, body = self._get("/api/mobile/v1/filters/options?source=timeoff&view=%s" % VIEW)
        self.assertEqual(status, 200, body)
        self.assertEqual([o["option"] for o in body["data"]["options"]],
                         ["month", "status", "leave_type"])

    def test_search_is_not_a_stored_option(self):
        """It moved to `?search=` on the listings. Neither dispatch route
        accepts it any more."""
        status, _body = self._get(
            "/api/mobile/v1/filters?view=%s&source=timeoff&option=" % VIEW + "search")
        self.assertEqual(status, 404)
        status, body = self._apply("timeoff", "search", {"query": "Annual"},
                                   view=VIEW)
        self.assertEqual(status, 404, body)
        self.assertEqual(body["code"], "unknown_option")

    def test_month_advertises_the_custom_range(self):
        """`custom_range_available` is computed from OPTIONS, so it is true
        here exactly because the source declares `date_range`."""
        status, body = self._get("/api/mobile/v1/filters?view=%s&source=timeoff&option=" % VIEW + "month")
        self.assertEqual(status, 200, body)
        self.assertTrue(body["data"]["custom_range_available"])

    def test_date_range_is_appliable_but_not_a_menu_entry(self):
        """Same shape as expenses: reached from the month panel, so it has no
        menu row and no value list of its own."""
        status, body = self._get("/api/mobile/v1/filters/options?source=timeoff&view=%s" % VIEW)
        self.assertNotIn("date_range",
                         [o["option"] for o in body["data"]["options"]])
        status, _body = self._get(
            "/api/mobile/v1/filters?view=%s&source=timeoff&option=" % VIEW + "date_range")
        self.assertEqual(status, 404)
        status, body = self._apply("timeoff", "date_range", {
            "from_date": "2026-01-01", "to_date": "2026-12-31"}, view=VIEW)
        self.assertEqual(status, 200, body)

    def test_unknown_option_names_the_timeoff_options(self):
        status, body = self._get(
            "/api/mobile/v1/filters?view=%s&source=timeoff&option=" % VIEW + "category")
        self.assertEqual(status, 404, body)
        self.assertEqual(body["code"], "unknown_option")
        self.assertIn("month", body["message"])

    def test_status_values_are_the_stages_the_rows_show(self):
        """Per view: every stage a row in that view is badged with is offered,
        and nothing else is."""
        for view in ("upcoming", "history"):
            status, body = self._get(
                "/api/mobile/v1/filters?view=%s&source=timeoff&option=status" % view)
            self.assertEqual(status, 200, body)
            offered = {i["id"] for i in body["data"]["items"]}
            shown = {row["stage"] for group in self._list(view)["leaves"]
                     for row in group["leaves"]}
            self.assertEqual(offered, shown, view)

    def test_leave_type_values_are_the_types_in_the_view(self):
        status, body = self._get(
            "/api/mobile/v1/filters?view=%s&source=timeoff&option=" % VIEW + "leave_type")
        self.assertEqual(status, 200, body)
        labels = [i["label"] for i in body["data"]["items"]]
        self.assertIn("TP Annual Leave", labels)
        self.assertIn("TP Sick Leave", labels)

    def test_month_buckets_come_from_leave_dates(self):
        status, body = self._get(
            "/api/mobile/v1/filters?view=%s&source=timeoff&option=" % VIEW + "month")
        self.assertEqual(status, 200, body)
        self.assertEqual(body["data"]["buckets"][0]["key"], "recent")
        keys = {b["key"] for b in body["data"]["buckets"]}
        self.assertIn(str(_monday(4).year), keys)

    def test_every_option_clears_on_null_missing_and_empty(self):
        cases = [
            ("status", {"status_ids": ["approved"]},
             [{"status_ids": None}, {}, {"status_ids": []}], "status_ids"),
            ("leave_type", {"leave_type_ids": [self.annual.id]},
             [{"leave_type_ids": None}, {}, {"leave_type_ids": []}],
             "leave_type_ids"),
            ("month", {"month_ids": ["%04d-%02d" % (_monday(4).year, _monday(4).month)]},
             [{"month_ids": None}, {}, {"month_ids": []}], "month_ids"),
        ]
        for option, applied, clearers, key in cases:
            for clearer in clearers:
                self._apply("timeoff", option, applied, view=VIEW)
                status, body = self._apply("timeoff", option, clearer, view=VIEW)
                self.assertEqual(status, 200, body)
                self.assertTrue(body["data"]["cleared"], (option, clearer))
                self.assertEqual(body["data"]["active"][key], [], (option, clearer))

    def test_active_no_longer_carries_a_query_key(self):
        """`query` left the active payload with the option."""
        self.assertNotIn("query", self._active("timeoff", VIEW))

    def test_malformed_values_are_rejected(self):
        status, body = self._apply("timeoff", "status", {"status_ids": ["nope"]}, view=VIEW)
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "invalid_status_ids")
        status, body = self._apply("timeoff", "leave_type",
                                   {"leave_type_ids": "all"}, view=VIEW)
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "invalid_leave_type_ids")

    @staticmethod
    def _around(day, before=3, after=3):
        return ((day - timedelta(days=before)).isoformat(),
                (day + timedelta(days=after)).isoformat())

    def test_date_range_narrows_its_own_view(self):
        """A window around the future Annual leave keeps it and drops the
        future Sick one -- and leaves history entirely alone."""
        start, end = self._around(_monday(4))
        self._apply("timeoff", "date_range",
                    {"from_date": start, "to_date": end}, view="upcoming")
        self.assertEqual(self._ids("upcoming"), {self.future_annual.id})
        self.assertEqual(self._ids("history"),
                         {self.past_annual.id, self.past_sick.id},
                         "history must not see upcoming's range")

    def test_date_range_covering_the_past_narrows_history(self):
        start, end = self._around(_monday(-8))
        self._apply("timeoff", "date_range",
                    {"from_date": start, "to_date": end}, view="history")
        self.assertEqual(self._ids("history"), {self.past_annual.id})
        self.assertEqual(self._ids("upcoming"),
                         {self.future_annual.id, self.future_sick.id},
                         "upcoming must not see history's range")

    def test_applying_a_date_range_clears_selected_months(self):
        day = _monday(4)
        self._apply("timeoff", "month",
                    {"month_ids": ["%04d-%02d" % (day.year, day.month)]}, view=VIEW)
        start, end = self._around(day)
        _status, body = self._apply("timeoff", "date_range",
                                    {"from_date": start, "to_date": end}, view=VIEW)
        self.assertEqual(body["data"]["active"]["month_ids"], [])
        self.assertEqual(body["data"]["active"]["date_range"],
                         {"from_date": start, "to_date": end})

    def test_applying_months_clears_an_active_date_range(self):
        start, end = self._around(_monday(4))
        self._apply("timeoff", "date_range",
                    {"from_date": start, "to_date": end}, view=VIEW)
        day = _monday(4)
        _status, body = self._apply(
            "timeoff", "month",
            {"month_ids": ["%04d-%02d" % (day.year, day.month)]}, view=VIEW)
        self.assertIsNone(body["data"]["active"]["date_range"])
        self.assertEqual(body["data"]["active"]["month_ids"],
                         ["%04d-%02d" % (day.year, day.month)])

    def test_date_range_clears_on_both_null_and_empty_body(self):
        start, end = self._around(_monday(4))
        for clearer in ({"from_date": None, "to_date": None}, {}):
            self._apply("timeoff", "date_range",
                        {"from_date": start, "to_date": end}, view=VIEW)
            status, body = self._apply("timeoff", "date_range", clearer, view=VIEW)
            self.assertEqual(status, 200, body)
            self.assertTrue(body["data"]["cleared"], clearer)
            self.assertIsNone(body["data"]["active"]["date_range"], clearer)

    def test_partial_and_reversed_ranges_are_rejected(self):
        """Identical rule to expenses -- one shared implementation."""
        for payload in ({"from_date": "2026-01-01"},
                        {"to_date": "2026-12-31"},
                        {"from_date": "2026-01-01", "to_date": None},
                        {"from_date": "2026-12-31", "to_date": "2026-01-01"},
                        {"from_date": "nope", "to_date": "2026-01-01"}):
            status, body = self._apply("timeoff", "date_range", payload, view=VIEW)
            self.assertEqual(status, 400, payload)
            self.assertEqual(body["code"], "invalid_date_range", payload)

    def test_date_range_combines_with_status_and_leave_type(self):
        start, end = self._around(_monday(4))
        self._apply("timeoff", "date_range",
                    {"from_date": start, "to_date": end}, view=VIEW)
        self._apply("timeoff", "leave_type", {"leave_type_ids": [self.sick.id]},
                    view=VIEW)
        self.assertEqual(self._ids("upcoming"), set(),
                         "the only leave in that window is Annual, not Sick")
        self._apply("timeoff", "leave_type", {"leave_type_ids": [self.annual.id]},
                    view=VIEW)
        self.assertEqual(self._ids("upcoming"), {self.future_annual.id})

    def test_a_range_yields_one_range_headed_group(self):
        start, end = self._around(_monday(4))
        self._apply("timeoff", "date_range",
                    {"from_date": start, "to_date": end}, view=VIEW)
        data = self._list("upcoming")
        self.assertEqual(sorted(data.keys()), ["leaves", "pagination"])
        self.assertEqual(len(data["leaves"]), 1)

    def test_unfiltered_lists_split_past_from_future(self):
        self.assertEqual(self._ids("history"),
                         {self.past_annual.id, self.past_sick.id})
        self.assertEqual(self._ids("upcoming"),
                         {self.future_annual.id, self.future_sick.id})

    def test_leave_type_filter_narrows_only_its_own_view(self):
        self._apply("timeoff", "leave_type", {"leave_type_ids": [self.sick.id]},
                    view="upcoming")
        self.assertEqual(self._ids("upcoming"), {self.future_sick.id})
        self.assertEqual(self._ids("history"),
                         {self.past_annual.id, self.past_sick.id},
                         "history must be untouched by an upcoming filter")

    def test_status_filter_narrows_only_its_own_view(self):
        self._apply("timeoff", "status", {"status_ids": ["approved"]},
                    view="history")
        self.assertEqual(self._ids("history"), {self.past_annual.id})
        self.assertEqual(self._ids("upcoming"),
                         {self.future_annual.id, self.future_sick.id},
                         "upcoming must be untouched by a history filter")

    def test_status_and_leave_type_combine_with_AND(self):
        """Status and leave type filters combine with AND, not union."""
        self._apply("timeoff", "status", {"status_ids": ["approved"]}, view=VIEW)
        self._apply("timeoff", "leave_type", {"leave_type_ids": [self.sick.id]},
                    view=VIEW)
        self.assertEqual(self._ids(VIEW), set(),
                         "no upcoming leave is both approved and sick")

    def test_status_and_leave_type_that_do_intersect(self):
        self._apply("timeoff", "status", {"status_ids": ["approved"]}, view=VIEW)
        self._apply("timeoff", "leave_type", {"leave_type_ids": [self.annual.id]},
                    view=VIEW)
        self.assertEqual(self._ids(VIEW), {self.future_annual.id})

    def test_a_filter_on_one_view_does_not_reach_the_other(self):
        """A filter on Upcoming does not affect History, and vice versa."""
        self._apply("timeoff", "leave_type", {"leave_type_ids": [self.annual.id]},
                    view="upcoming")
        self.assertEqual(self._ids("upcoming"), {self.future_annual.id})
        self.assertEqual(self._ids("history"),
                         {self.past_annual.id, self.past_sick.id},
                         "history saw a filter that was applied to upcoming")

    def test_each_view_holds_its_own_independent_filter(self):
        """Different filters on each view at the same time."""
        self._apply("timeoff", "leave_type", {"leave_type_ids": [self.annual.id]},
                    view="upcoming")
        self._apply("timeoff", "leave_type", {"leave_type_ids": [self.sick.id]},
                    view="history")
        self.assertEqual(self._ids("upcoming"), {self.future_annual.id})
        self.assertEqual(self._ids("history"), {self.past_sick.id})
        self.assertEqual(self._active("timeoff", "upcoming")["leave_type_ids"],
                         [self.annual.id])
        self.assertEqual(self._active("timeoff", "history")["leave_type_ids"],
                         [self.sick.id])

    def test_each_view_clears_independently(self):
        self._apply("timeoff", "status", {"status_ids": ["approved"]},
                    view="upcoming")
        self._apply("timeoff", "status", {"status_ids": ["approved"]},
                    view="history")
        self._apply("timeoff", "status", {}, view="upcoming")
        self.assertEqual(self._active("timeoff", "upcoming")["status_ids"], [])
        self.assertEqual(self._active("timeoff", "history")["status_ids"],
                         ["approved"],
                         "clearing upcoming must not clear history")
        self.assertEqual(self._ids("upcoming"),
                         {self.future_annual.id, self.future_sick.id})
        self.assertEqual(self._ids("history"), {self.past_annual.id})

    def test_view_is_required_for_timeoff(self):
        status, body = self._get("/api/mobile/v1/filters?source=timeoff&option=month")
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "missing_view")
        status, body = self._apply("timeoff", "status", {"status_ids": []})
        self.assertEqual(status, 400, body)
        self.assertEqual(body["code"], "missing_view")

    def test_an_unknown_view_is_rejected(self):
        status, body = self._apply("timeoff", "status", {"status_ids": []},
                                   view="sideways")
        self.assertEqual(status, 404, body)
        self.assertEqual(body["code"], "unknown_view")

    def test_responses_echo_the_view(self):
        _status, body = self._apply("timeoff", "status", {"status_ids": []},
                                    view="history")
        self.assertEqual(body["data"]["view"], "history")
        status, body = self._get(
            "/api/mobile/v1/filters/options?source=timeoff&view=history")
        self.assertEqual(body["data"]["view"], "history")
        for option in body["data"]["options"]:
            self.assertIn("view=history", option["url"])
        self.assertIn("view=history", body["data"]["apply_url"])

    def test_search_param_matches_the_reason(self):
        """`data.leaves[i].name` is `private_name or <type name>`, so the
        reason has to be searchable for the search to match what is shown."""
        self.assertEqual(self._ids("upcoming", search="wedding"),
                         {self.future_annual.id})
        self.assertEqual(self._ids("history", search="funeral"),
                         {self.past_annual.id})

    def test_reason_search_is_case_insensitive_and_partial(self):
        self.assertEqual(self._ids("upcoming", search="KERALA"),
                         {self.future_annual.id})
        self.assertEqual(self._ids("upcoming", search="Cousin"),
                         {self.future_annual.id})

    def test_reason_and_leave_type_are_ORed(self):
        """"Annual" hits the TYPE of one row; "wedding" hits the REASON of
        the same row -- and a term matching neither returns nothing."""
        self.assertEqual(self._ids("upcoming", search="Annual"),
                         {self.future_annual.id})
        self.assertEqual(self._ids("upcoming", search="wedding"),
                         {self.future_annual.id})
        self.assertEqual(self._ids("upcoming", search="zzz"), set())

    def test_reason_search_does_not_leak_another_employees_leave(self):
        """The reason lookup runs under sudo, so it must stay pinned to the
        caller's own employee."""
        other = self.env["hr.employee"].sudo().create({
            "name": "TP Other", "company_id": self.env.ref("base.main_company").id})
        theirs = self.env["hr.leave"].sudo().create({
            "employee_id": other.id, "holiday_status_id": self.annual.id,
            "request_date_from": _monday(5), "request_date_to": _monday(5)})
        theirs.sudo().private_name = "Cousin wedding in Kerala"
        self.assertEqual(self._ids("upcoming", search="wedding"),
                         {self.future_annual.id},
                         "another employee's leave matched the reason search")

    def test_reason_search_ands_with_a_stored_filter(self):
        self._apply("timeoff", "leave_type", {"leave_type_ids": [self.sick.id]},
                    view="upcoming")
        self.assertEqual(self._ids("upcoming", search="wedding"), set(),
                         "the wedding leave is Annual, excluded by the filter")

    def test_search_param_matches_the_leave_type_name(self):
        self.assertEqual(self._ids("upcoming", search="Sick"),
                         {self.future_sick.id})
        self.assertEqual(self._ids("history", search="Sick"),
                         {self.past_sick.id})

    def test_search_param_is_transient(self):
        """Nothing is stored, so the next request without it is unfiltered."""
        self.assertEqual(self._ids("upcoming", search="Sick"),
                         {self.future_sick.id})
        self.assertEqual(self._ids("upcoming"),
                         {self.future_annual.id, self.future_sick.id})

    def test_blank_search_is_no_search(self):
        for blank in ("", "%20%20"):
            self.assertEqual(self._ids("upcoming", search=blank),
                             {self.future_annual.id, self.future_sick.id}, blank)

    def test_search_param_ands_with_a_stored_filter(self):
        self._apply("timeoff", "leave_type", {"leave_type_ids": [self.annual.id]},
                    view="upcoming")
        self.assertEqual(self._ids("upcoming", search="Sick"), set(),
                         "Sick is excluded by the stored leave-type filter")
        self.assertEqual(self._ids("upcoming", search="Annual"),
                         {self.future_annual.id})

    def test_search_param_is_per_request_not_per_view(self):
        """Searching one listing cannot affect the other -- there is no
        state to leak."""
        self.assertEqual(self._ids("upcoming", search="Sick"),
                         {self.future_sick.id})
        self.assertEqual(self._ids("history"),
                         {self.past_annual.id, self.past_sick.id})

    def test_search_param_combines_with_a_status_filter(self):
        self._apply("timeoff", "status", {"status_ids": ["approved"]}, view=VIEW)
        self.assertEqual(self._ids("upcoming", search="Annual"),
                         {self.future_annual.id})

    def test_month_filter_narrows_to_the_selected_month(self):
        day = _monday(4)
        self._apply("timeoff", "month",
                    {"month_ids": ["%04d-%02d" % (day.year, day.month)]}, view=VIEW)
        self.assertIn(self.future_annual.id, self._ids("upcoming"))

    def test_pagination_still_counts_the_filtered_set(self):
        self._apply("timeoff", "leave_type", {"leave_type_ids": [self.sick.id]},
                    view="history")
        self.assertEqual(self._list("history")["pagination"]["total"], 1)

    def test_top_level_keys_are_unchanged(self):
        """`leaves` changed shape; `pagination` and the key set did not."""
        data = self._list("upcoming")
        self.assertEqual(sorted(data.keys()), ["leaves", "pagination"])
        for group in data["leaves"]:
            self.assertEqual(sorted(group.keys()), ["leaves", "timeline"])


@tagged("post_install", "-at_install")
class TestPayslipFiltersApi(DispatchMixin, HttpCase):
    """`source=payslip` on the same dispatch, and `/payslip/list`."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.user = Users.create({
            "name": "TP Payslip User", "login": LOGIN, "password": PASSWORD,
            "group_ids": [(4, mobile_group.id), (4, internal.id)]})
        cls.employee = Employee.create({
            "name": "TP Payslip User", "company_id": company.id,
            "user_id": cls.user.id})

    def _slip(self, name, year, month):
        """A visible payslip, with `state` set by SQL to avoid payroll compute needing a contract."""
        last = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
        payslip = self.env["hr.payslip"].sudo().create({
            "employee_id": self.employee.id, "name": name,
            "date_from": date(year, month, 1),
            "date_to": date(year, month, last)})
        self.env.cr.execute(
            "UPDATE hr_payslip SET state = 'validated' WHERE id = %s",
            [payslip.id])
        self.env.invalidate_all()
        return payslip

    def _list(self, search=None):
        suffix = "&search=%s" % search if search else ""
        status, body = self._get(
            "/api/mobile/v1/payslip/list?page=1&page_size=50%s" % suffix)
        self.assertEqual(status, 200, body)
        return body["data"]

    def _ids(self, search=None):
        return {row["id"] for row in self._list(search)["payslips"]}

    def setUp(self):
        super().setUp()
        self.june = self._slip("SLIP/JUNE", 2026, 6)
        self.july = self._slip("SLIP/JULY", 2026, 7)
        self.august = self._slip("SLIP/AUGUST", 2026, 8)
        # Same month, previous year: keeps the year half of the label tested.
        self.june_last_year = self._slip("SLIP/JUNE-PRIOR", 2025, 6)
        self.addCleanup(lambda: self._apply("payslip", "month", {}))

    def test_menu_lists_only_month(self):
        status, body = self._get("/api/mobile/v1/filters/options?source=payslip")
        self.assertEqual(status, 200, body)
        self.assertEqual([o["option"] for o in body["data"]["options"]], ["month"])

    def test_options_the_source_does_not_have_are_rejected(self):
        for option in ("category", "status", "leave_type", "date_range", "search"):
            status, body = self._apply("payslip", option, {})
            self.assertEqual(status, 404, (option, body))
            self.assertEqual(body["code"], "unknown_option", option)

    def test_month_buckets_come_from_payslip_dates(self):
        status, body = self._get(
            "/api/mobile/v1/filters?source=payslip&option=month&bucket=2026")
        self.assertEqual(status, 200, body)
        self.assertEqual([i["id"] for i in body["data"]["items"]],
                         ["2026-08", "2026-07", "2026-06"])

    def test_month_clears(self):
        for clearer in ({"month_ids": None}, {}, {"month_ids": []}):
            self._apply("payslip", "month", {"month_ids": ["2026-07"]})
            status, body = self._apply("payslip", "month", clearer)
            self.assertEqual(status, 200, body)
            self.assertTrue(body["data"]["cleared"], clearer)
            self.assertEqual(body["data"]["active"]["month_ids"], [])
        self.assertNotIn("query", self._active("payslip"))

    def test_unfiltered_list_has_every_payslip(self):
        self.assertEqual(self._ids(),
                         {self.june.id, self.july.id, self.august.id,
                          self.june_last_year.id})

    def test_month_filter_narrows_the_list(self):
        self._apply("payslip", "month", {"month_ids": ["2026-07"]})
        self.assertEqual(self._ids(), {self.july.id})

    def test_search_param_matches_the_reference(self):
        self.assertEqual(self._ids(search="AUGUST"), {self.august.id})

    def test_search_param_is_transient(self):
        self.assertEqual(self._ids(search="AUGUST"), {self.august.id})
        self.assertEqual(self._ids(),
                         {self.june.id, self.july.id, self.august.id,
                          self.june_last_year.id})

    def test_search_param_matches_the_period_the_row_displays(self):
        """The row shows "June 2026", rendered from `date_from` rather than
        stored, so a month name has to be matched through the dates."""
        self.assertEqual(self._ids(search="June"),
                         {self.june.id, self.june_last_year.id})

    def test_search_matches_the_full_month_and_year_label(self):
        """Search matches the full month-and-year label shown on the row, e.g. "September 2026"."""
        self.assertEqual(self._ids(search="June 2026"), {self.june.id})
        self.assertEqual(self._ids(search="June%202025"),
                         {self.june_last_year.id})

    def test_the_year_half_of_the_label_must_match_exactly(self):
        """A prefix match on the year would make 2025 and 2026 one character
        apart from a silent wrong answer."""
        self.assertEqual(self._ids(search="June%20202"), set())
        self.assertEqual(self._ids(search="June%202027"), set())

    def test_abbreviated_month_names_work_with_a_year(self):
        self.assertEqual(self._ids(search="Jun%202026"), {self.june.id})

    def test_a_partial_month_prefix_matches_every_month_it_prefixes(self):
        """"Ju 2026" is genuinely ambiguous between June and July, and the
        year still pins the year -- 2025's June stays out."""
        self.assertEqual(self._ids(search="Ju%202026"),
                         {self.june.id, self.july.id})

    def test_label_search_is_case_and_space_insensitive(self):
        for term in ("june%202026", "JUNE%202026", "June%20%202026"):
            self.assertEqual(self._ids(search=term), {self.june.id}, term)

    def test_a_bare_year_is_unchanged(self):
        """Still served by the reference match, not by a year-wide window --
        so it cannot silently widen to every payslip of that year."""
        self.assertEqual(self._ids(search="2026"), set(),
                         "no reference in this fixture contains 2026")

    def test_search_param_and_stored_month_combine(self):
        self._apply("payslip", "month", {"month_ids": ["2026-06"]})
        self.assertEqual(self._ids(search="SLIP"), {self.june.id})
        self.assertEqual(self._ids(search="AUGUST"), set(),
                         "August is excluded by the stored month filter")

    def test_years_index_stays_unfiltered(self):
        """`years` is the year PICKER -- it must keep offering every year the
        employee has payslips in, or a filter would hide its own way out."""
        before = self._list()["years"]
        self._apply("payslip", "month", {"month_ids": ["2026-07"]})
        self.assertEqual(self._list()["years"], before)

    def test_the_response_stays_flat(self):
        data = self._list()
        self.assertEqual(sorted(data.keys()),
                         ["pagination", "payslips", "year", "years"])

    def test_pagination_counts_the_filtered_set(self):
        self._apply("payslip", "month", {"month_ids": ["2026-07"]})
        self.assertEqual(self._list()["pagination"]["total"], 1)


@tagged("post_install", "-at_install")
class TestTimeoffMonthGrouping(DispatchMixin, HttpCase):
    """`data.leaves` on both listings is `[{"timeline", "leaves"}]`.
    Dates are pinned to 2020/2099 weekdays so month boundaries are deterministic."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")
        cls.user = cls.env["res.users"].sudo().create({
            "name": "TP Group User", "login": LOGIN, "password": PASSWORD,
            "tz": "UTC",
            "group_ids": [(4, mobile_group.id), (4, internal.id)]})
        cls.employee = cls.env["hr.employee"].sudo().create({
            "name": "TP Group User", "company_id": company.id,
            "user_id": cls.user.id})
        cls.leave_type = cls.env["hr.leave.type"].sudo().create({
            "name": "TP Group Leave", "requires_allocation": False,
            "request_unit": "day", "leave_validation_type": "hr"})

        cls.ids_by_date = {}
        for day in ("2020-03-20", "2020-03-10", "2020-02-05", "2020-01-15",
                    "2099-01-12", "2099-01-20", "2099-02-05", "2099-03-16"):
            value = date.fromisoformat(day)
            leave = cls.env["hr.leave"].sudo().create({
                "employee_id": cls.employee.id,
                "holiday_status_id": cls.leave_type.id,
                "request_date_from": value, "request_date_to": value})
            cls.ids_by_date[day] = leave.id

    def setUp(self):
        super().setUp()
        self.addCleanup(self._clear)

    def _clear(self):
        for view in ("upcoming", "history"):
            for option in ("month", "status", "leave_type", "date_range"):
                self._apply("timeoff", option, {}, view=view)

    def _groups(self, which, page=1, page_size=50, search=None):
        suffix = "&search=%s" % search if search else ""
        status, body = self._get(
            "/api/mobile/v1/timeoff/%s?page=%s&page_size=%s%s"
            % (which, page, page_size, suffix))
        self.assertEqual(status, 200, body)
        return body["data"]

    @staticmethod
    def _shape(data):
        """`[("March 2020", 2), ...]` -- readable failure diffs."""
        return [(g["timeline"], len(g["leaves"])) for g in data["leaves"]]

    def test_history_groups_every_month_newest_first(self):
        self.assertEqual(self._shape(self._groups("history")), [
            ("March 2020", 2), ("February 2020", 1), ("January 2020", 1)])

    def test_upcoming_groups_every_month_soonest_first(self):
        """Upcoming groups are soonest first, matching its `asc` order across pages."""
        self.assertEqual(self._shape(self._groups("upcoming")), [
            ("January 2099", 2), ("February 2099", 1), ("March 2099", 1)])

    def test_each_group_holds_the_existing_leave_objects(self):
        """Only the nesting changed -- the leave payload itself did not."""
        leave = self._groups("history")["leaves"][0]["leaves"][0]
        for key in ("id", "name", "leave_type", "date_from", "date_to",
                    "days", "stage", "stage_display"):
            self.assertIn(key, leave)

    def test_a_leave_groups_under_its_date_from_month_only(self):
        """A leave spanning a month boundary appears once, under the month it
        STARTS in -- never duplicated into the month it ends in."""
        span = self.env["hr.leave"].sudo().create({
            "employee_id": self.employee.id,
            "holiday_status_id": self.leave_type.id,
            "request_date_from": date(2099, 4, 29),
            "request_date_to": date(2099, 5, 4)})
        groups = self._groups("upcoming")["leaves"]
        homes = [g["timeline"] for g in groups
                 if span.id in {row["id"] for row in g["leaves"]}]
        self.assertEqual(homes, ["April 2099"])

    def test_a_page_ending_mid_run_returns_two_groups(self):
        """page_size=3 over [Mar, Mar, Feb, Jan]: the page crosses the
        March/February boundary, so it is two groups, not one."""
        self.assertEqual(self._shape(self._groups("history", 1, 3)),
                         [("March 2020", 2), ("February 2020", 1)])
        self.assertEqual(self._shape(self._groups("history", 2, 3)),
                         [("January 2020", 1)])

    def test_a_month_split_across_pages_repeats_its_heading(self):
        self.assertEqual(self._shape(self._groups("history", 1, 1)),
                         [("March 2020", 1)])
        self.assertEqual(self._shape(self._groups("history", 2, 1)),
                         [("March 2020", 1)],
                         "the second March leave opens page 2 under the same heading")

    def test_pagination_counts_leaves_not_groups(self):
        data = self._groups("history", 1, 3)
        self.assertEqual(data["pagination"]["total"], 4)
        self.assertEqual(data["pagination"]["page_size"], 3)
        self.assertEqual(sum(len(g["leaves"]) for g in data["leaves"]), 3)

    def test_groups_flatten_back_to_exactly_the_page(self):
        """Bucketing must not add, drop or reorder a row."""
        expected = [self.ids_by_date[d] for d in
                    ("2020-03-20", "2020-03-10", "2020-02-05", "2020-01-15")]
        seen = []
        for page in (1, 2):
            data = self._groups("history", page, 2)
            seen += [row["id"] for g in data["leaves"] for row in g["leaves"]]
        self.assertEqual(seen, expected)

    def test_an_empty_page_has_no_groups(self):
        self.assertEqual(self._groups("history", 9, 10)["leaves"], [])

    def test_month_filter_groups_only_the_selected_months(self):
        self._apply("timeoff", "month",
                    {"month_ids": ["2020-02", "2020-01"]}, view="history")
        self.assertEqual(self._shape(self._groups("history")),
                         [("February 2020", 1), ("January 2020", 1)])

    def test_status_filter_still_groups_by_month(self):
        self._apply("timeoff", "status", {"status_ids": ["pending"]},
                    view="history")
        self.assertEqual(self._shape(self._groups("history")), [
            ("March 2020", 2), ("February 2020", 1), ("January 2020", 1)])
        self._apply("timeoff", "status", {"status_ids": ["approved"]},
                    view="history")
        self.assertEqual(self._groups("history")["leaves"], [])

    def test_leave_type_filter_still_groups_by_month(self):
        self._apply("timeoff", "leave_type",
                    {"leave_type_ids": [self.leave_type.id]}, view="upcoming")
        self.assertEqual(len(self._groups("upcoming")["leaves"]), 3)

    def test_search_still_groups_by_month(self):
        self.assertEqual(self._shape(self._groups("history", search="TP%20Group")),
                         [("March 2020", 2), ("February 2020", 1),
                          ("January 2020", 1)])

    def test_date_range_is_one_flat_group_headed_by_the_range(self):
        self._apply("timeoff", "date_range",
                    {"from_date": "2020-01-01", "to_date": "2020-03-31"},
                    view="history")
        data = self._groups("history")
        self.assertEqual(len(data["leaves"]), 1, "a range must not be re-cut by month")
        self.assertEqual(data["leaves"][0]["timeline"], "Jan 1 - Mar 31, 2020")
        self.assertEqual([row["id"] for row in data["leaves"][0]["leaves"]],
                         [self.ids_by_date[d] for d in
                          ("2020-03-20", "2020-03-10", "2020-02-05", "2020-01-15")])

    def test_date_range_stays_one_group_across_pages(self):
        self._apply("timeoff", "date_range",
                    {"from_date": "2020-01-01", "to_date": "2020-03-31"},
                    view="history")
        for page in (1, 2):
            data = self._groups("history", page, 3)
            self.assertEqual(len(data["leaves"]), 1, page)
            self.assertEqual(data["leaves"][0]["timeline"], "Jan 1 - Mar 31, 2020")

    def test_the_range_on_one_view_does_not_regroup_the_other(self):
        """Grouping reads the SAME per-view state as the domain."""
        self._apply("timeoff", "date_range",
                    {"from_date": "2020-01-01", "to_date": "2020-03-31"},
                    view="history")
        self.assertEqual(self._shape(self._groups("upcoming")), [
            ("January 2099", 2), ("February 2099", 1), ("March 2099", 1)])


@tagged("post_install", "-at_install")
class TestTimeoffViewScopedValues(DispatchMixin, HttpCase):
    """Each view's filter value lists come only from that view's leaves.
    A future cancelled leave belongs to neither view, so its values must appear in neither."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")
        cls.user = cls.env["res.users"].sudo().create({
            "name": "TP Scope User", "login": LOGIN, "password": PASSWORD,
            "tz": "UTC",
            "group_ids": [(4, mobile_group.id), (4, internal.id)]})
        cls.employee = cls.env["hr.employee"].sudo().create({
            "name": "TP Scope User", "company_id": company.id,
            "user_id": cls.user.id})
        LeaveType = cls.env["hr.leave.type"].sudo()
        cls.alpha, cls.bravo, cls.charlie = [LeaveType.create({
            "name": name, "requires_allocation": False,
            "request_unit": "day", "leave_validation_type": "hr"})
            for name in ("TP Scope Alpha", "TP Scope Bravo", "TP Scope Charlie")]

        for day, leave_type, state in (
                ("2020-02-05", cls.alpha, "validate"),
                ("2020-01-15", cls.alpha, "refuse"),
                ("2099-03-16", cls.bravo, None),
                ("2099-04-14", cls.bravo, "validate"),
                ("2099-05-12", cls.charlie, "cancel")):
            value = date.fromisoformat(day)
            leave = cls.env["hr.leave"].sudo().create({
                "employee_id": cls.employee.id,
                "holiday_status_id": leave_type.id,
                "request_date_from": value, "request_date_to": value})
            if state:
                leave.write({"state": state})

    def _values(self, view, option, bucket=None):
        suffix = "&bucket=%s" % bucket if bucket else ""
        status, body = self._get(
            "/api/mobile/v1/filters?source=timeoff&view=%s&option=%s%s"
            % (view, option, suffix))
        self.assertEqual(status, 200, body)
        return body["data"]

    def test_history_buckets_hold_only_past_years(self):
        keys = [b["key"] for b in self._values("history", "month")["buckets"]]
        self.assertEqual(keys, ["recent", "2020"])

    def test_upcoming_buckets_hold_only_future_years(self):
        keys = [b["key"] for b in self._values("upcoming", "month")["buckets"]]
        self.assertEqual(keys, ["recent", "2099"])

    def test_recent_months_differ_per_view(self):
        self.assertEqual(
            [i["id"] for i in self._values("history", "month", "recent")["items"]],
            ["2020-02", "2020-01"])
        self.assertEqual(
            [i["id"] for i in self._values("upcoming", "month", "recent")["items"]],
            ["2099-04", "2099-03"],
            "May 2099 holds only a cancelled leave, which upcoming never lists")

    def test_a_year_bucket_from_the_other_view_is_empty(self):
        self.assertEqual(self._values("history", "month", "2099")["items"], [])
        self.assertEqual(self._values("upcoming", "month", "2020")["items"], [])

    def test_history_status_offers_only_its_stages(self):
        ids = [i["id"] for i in self._values("history", "status")["items"]]
        self.assertEqual(ids, ["approved", "rejected"])

    def test_upcoming_status_offers_only_its_stages(self):
        ids = [i["id"] for i in self._values("upcoming", "status")["items"]]
        self.assertEqual(ids, ["pending", "approved"],
                         "no rejected leave in upcoming, and the cancelled one "
                         "is listed by neither view")

    def test_status_keeps_lifecycle_order(self):
        """Offered in pending/approved/rejected/cancelled order, not in the
        order the data happens to come back in."""
        ids = [i["id"] for i in self._values("upcoming", "status")["items"]]
        self.assertEqual(ids, sorted(ids, key=["pending", "approved",
                                               "rejected", "cancelled"].index))

    def test_history_leave_types_are_only_its_own(self):
        labels = [i["label"] for i in self._values("history", "leave_type")["items"]]
        self.assertEqual(labels, ["TP Scope Alpha"])

    def test_upcoming_leave_types_are_only_its_own(self):
        labels = [i["label"] for i in self._values("upcoming", "leave_type")["items"]]
        self.assertEqual(labels, ["TP Scope Bravo"],
                         "Charlie's only leave is cancelled, listed by neither view")

    def test_every_offered_value_selects_at_least_one_row(self):
        """Every offered filter value, applied to its own view, yields a non-empty listing."""
        cases = []
        for view in ("upcoming", "history"):
            for item in self._values(view, "status")["items"]:
                cases.append((view, "status", {"status_ids": [item["id"]]}))
            for item in self._values(view, "leave_type")["items"]:
                cases.append((view, "leave_type", {"leave_type_ids": [item["id"]]}))
            for item in self._values(view, "month", "recent")["items"]:
                cases.append((view, "month", {"month_ids": [item["id"]]}))
        self.assertTrue(cases)
        dead = []
        for view, option, payload in cases:
            self._apply("timeoff", option, payload, view=view)
            status, body = self._get(
                "/api/mobile/v1/timeoff/%s?page=1&page_size=50" % view)
            if not body["data"]["leaves"]:
                dead.append((view, option, payload))
            self._apply("timeoff", option, {}, view=view)
        self.assertEqual(dead, [], "offered values that select nothing")
