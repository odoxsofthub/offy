import logging
import re
import time

from odoo.tests import tagged

from .common import HttpCase

_logger = logging.getLogger(__name__)

API_PREFIX = "/api/mobile/"
# Slower than this on the test server counts as a hang/bottleneck.
SLOW_SECONDS = 5.0
MISSING_ID = "999999999"
ARG_RE = re.compile(r"<[^>]+>")

# Routes that answer without a Bearer token by design (credentials, refresh token or signed `t=` link).
NO_BEARER_ROUTES = {
    "/api/mobile/v1/auth/login",
    "/api/mobile/v1/auth/refresh",
    "/api/mobile/v1/payslip/<payslip_id>/file",
    "/api/mobile/v1/employees/<employee_id>/avatar",
    "/api/mobile/v1/partners/<partner_id>/avatar",
    "/api/mobile/v1/profile/documents/<attachment_id>/download",
    "/api/mobile/v1/profile/documents/<attachment_id>/preview",
    "/api/mobile/v1/log-note/attachments/<attachment_id>",
}

WRONG_TYPES_JSON = {
    "login": 123, "password": [], "refreshToken": 5, "companyIds": "x",
    "date": "2026-02-30", "date_from": "not-a-date", "date_to": [],
    "start": {}, "stop": "zz", "month": 13, "year": "abc",
    "page": "x", "limit": -5, "offset": "y", "status": 5, "type": "bogus",
    "name": None, "amount": "abc", "total_amount": "abc", "product_id": "x",
    "leave_type_id": "x", "holiday_status_id": "x", "request_unit": 9,
    "notes": 123, "description": [], "existing_attachments": "{",
    "res_model": "res.users", "res_id": "x", "body": None,
    "firebase_id": 7, "token": [], "platform": {}, "partner_ids": "x",
    "device_type": 9, "title": 5, "source": 5, "reason": [],
    "latitude": "north", "longitude": "east", "filter_id": "x", "filters": "x",
}
WRONG_TYPES_QUERY = {
    "date": "2026-02-30", "date_from": "not-a-date", "date_to": "x",
    "month": "13", "year": "abc", "page": "x", "limit": "-5", "offset": "y",
    "status": "bogus", "type": "bogus", "res_model": "res.users", "res_id": "x",
    "q": "%", "search": "%", "width": "abc", "height": "-1", "t": "zz.zz",
    "before_id": "x", "filter_id": "x", "category_id": "x",
}


@tagged("-at_install", "post_install")
class TestEndpointSweep(HttpCase):
    """Every `/api/mobile/` route with no token, a bad token, a malformed body, invalid values
    and missing records: never a 5xx, never slow, always the JSON envelope."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.password = "endpoint_sweep_pw_1234"
        cls.user = cls.env["res.users"].sudo().create({
            "name": "Sweep User",
            "login": "sweep_user@test.com",
            "email": "sweep_user@test.com",
            "password": cls.password,
            "groups_id": [
                (4, cls.env.ref("base.group_user").id),
                (4, cls.env.ref("odx_mobile_connector.group_mobile_user").id),
            ],
        })
        cls.env["hr.employee"].sudo().create({
            "name": "Sweep User",
            "user_id": cls.user.id,
            "company_id": cls.user.company_id.id,
        })
        UserFeature = cls.env["mobile.user.feature"].sudo()
        linked = UserFeature.search([("user_id", "=", cls.user.id)]).feature_id
        missing = cls.env["mobile.feature"].sudo().search([]) - linked
        UserFeature.create([
            {"user_id": cls.user.id, "feature_id": feature.id} for feature in missing])
        cls.env.flush_all()

    def _routes(self):
        """(rule, method) for every mobile API route, as Odoo's router serves them."""
        # Odoo 18's `http.root.get_db_router()` needs a bound request; this is what it returns.
        router = self.env["ir.http"].routing_map()
        pairs = set()
        for rule in router.iter_rules():
            if not rule.rule.startswith(API_PREFIX):
                continue
            methods = set(rule.methods or ("GET", "POST")) - {"HEAD", "OPTIONS"}
            pairs.update((rule.rule, method) for method in methods)
        return sorted(pairs)

    def _login(self):
        resp = self.url_open("/api/mobile/v1/auth/login",
                             json={"login": self.user.login, "password": self.password})
        self.assertEqual(resp.status_code, 200, resp.text)
        return resp.json()["data"]

    def _call(self, label, rule, method, token=None, path_arg=MISSING_ID,
              json_body=None, raw=None, query=None, expect=None):
        path = ARG_RE.sub(path_arg, rule)
        headers = {}
        if token:
            headers["Authorization"] = "Bearer %s" % token
        kwargs = {}
        if raw is not None:
            headers["Content-Type"] = "application/json"
            kwargs["data"] = raw
        elif json_body is not None:
            kwargs["json"] = json_body
        start = time.monotonic()
        resp = self.url_open(path, method=method, headers=headers, params=query,
                             timeout=SLOW_SECONDS * 3, allow_redirects=False, **kwargs)
        elapsed = time.monotonic() - start
        _logger.info("SWEEP %-6s %-62s %-12s -> %s in %4.0f ms",
                     method, path, label, resp.status_code, elapsed * 1000)

        where = "%s %s [%s]" % (method, path, label)
        with self.subTest(call=where):
            self.assertLess(resp.status_code, 500,
                            "%s -> %s %s" % (where, resp.status_code, resp.text[:300]))
            self.assertLess(elapsed, SLOW_SECONDS, "%s took %.1fs" % (where, elapsed))
            if expect is not None:
                self.assertEqual(resp.status_code, expect,
                                 "%s -> %s %s" % (where, resp.status_code, resp.text[:300]))
            if resp.headers.get("Content-Type", "").startswith("application/json"):
                body = resp.json()
                self.assertIsInstance(body, dict, where)
                for key in ("success", "message", "data"):
                    self.assertIn(key, body, "%s: missing %r" % (where, key))
                if not body["success"]:
                    self.assertTrue(body.get("code"), "%s: error without code" % where)
        return resp

    def test_unauthenticated_calls_are_refused(self):
        for rule, method in self._routes():
            expect = None if rule in NO_BEARER_ROUTES else 401
            self._call("no-token", rule, method, expect=expect)
            self._call("bad-token", rule, method, token="not-a-real-token",
                       expect=expect)

    def test_invalid_input_never_breaks_an_endpoint(self):
        session = self._login()
        token = session["token"]
        for rule, method in self._routes():
            if rule == "/api/mobile/v1/auth/logout":
                continue
            has_args = bool(ARG_RE.search(rule))
            if method == "GET":
                self._call("plain", rule, method, token=token)
                self._call("bad-query", rule, method, token=token,
                           query=WRONG_TYPES_QUERY)
            else:
                self._call("empty", rule, method, token=token, json_body={})
                self._call("malformed", rule, method, token=token, raw='{"bad": ')
                self._call("wrong-types", rule, method, token=token,
                           json_body=WRONG_TYPES_JSON)
            if has_args:
                self._call("non-numeric", rule, method, token=token,
                           path_arg="abc", json_body={} if method != "GET" else None)

        # The token still works after the sweep, and logout ends it.
        self._call("still-valid", "/api/mobile/v1/home", "GET", token=token, expect=200)
        self._call("logout", "/api/mobile/v1/auth/logout", "POST", token=token,
                   json_body={"refreshToken": session["refreshToken"]}, expect=200)
        self._call("after-logout", "/api/mobile/v1/home", "GET", token=token, expect=401)
