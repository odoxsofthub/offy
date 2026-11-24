import base64
import time

from odoo.tests import HttpCase, tagged

from ..controllers.log_note import MENTION_AVATAR_FIELD
from ..controllers.main import MobileApiAuth

# 1x1 transparent PNG -- smallest thing `ir.binary` will accept as an image.
PNG_1PX = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk"
    "YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
)


@tagged("-at_install", "post_install")
class TestMobileLogNoteApi(HttpCase):
    """GET /log-note/mention-suggestions and /partners/<id>/avatar, authenticated via the real /auth/login."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Partner = cls.env["res.partner"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        portal_group = cls.env.ref("base.group_portal")
        company = cls.env.ref("base.main_company")

        cls.password = "log_note_api_pw_1234"
        cls.user = Users.create({
            "name": "Lognote Mobile User",
            "login": "log_note_api_user@test.com",
            "password": cls.password,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        # Login refuses employee-less accounts (see test_auth_employment_gate.py).
        cls.employee = Employee.create({
            "name": "Lognote Mobile User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })

        # Rare shared token so a search matches only these records.
        cls.marker = "Zqmention"

        cls.internal_user = Users.create({
            "name": "%s Internal" % cls.marker,
            "login": "log_note_internal@test.com",
            "email": "log_note_internal@test.com",
            "group_ids": [(4, internal_group.id)],
        })
        cls.internal_partner = cls.internal_user.partner_id
        cls.internal_partner.write({"image_1920": base64.b64encode(PNG_1PX)})

        cls.portal_user = Users.create({
            "name": "%s Portal" % cls.marker,
            "login": "log_note_portal@test.com",
            "email": "log_note_portal@test.com",
            "group_ids": [(6, 0, [portal_group.id])],
        })
        cls.portal_partner = cls.portal_user.partner_id

        cls.plain_partner = Partner.create({
            "name": "%s Contact" % cls.marker,
            "email": "log_note_contact@test.com",
        })

        cls.env.flush_all()

    def _token(self):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": "log_note_api_user@test.com",
                  "password": self.password},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"]

    def _get(self, path, token=None):
        headers = {"Authorization": "Bearer %s" % token} if token else {}
        resp = self.url_open(path, headers=headers)
        return resp.status_code, resp.json()

    def _path(self, url):
        """Strip scheme+host off an absolute URL -- `url_open` wants a path."""
        return "/" + url.split("://", 1)[1].split("/", 1)[1]

    def _avatar_url_for(self, token, partner):
        data = self._suggestions(token, "?search=%s" % self.marker)
        return next(s["image_url"] for s in data["suggestions"]
                    if s["id"] == partner.id)

    def _suggestions(self, token, query=""):
        status, body = self._get(
            "/api/mobile/v1/log-note/mention-suggestions%s" % query, token)
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"], body)
        return body["data"]

    def test_missing_token_rejected(self):
        status, body = self._get(
            "/api/mobile/v1/log-note/mention-suggestions")
        self.assertEqual(status, 401)
        self.assertFalse(body["success"])
        self.assertEqual(body["code"], "missing_access_token")

    def test_invalid_token_rejected(self):
        status, body = self._get(
            "/api/mobile/v1/log-note/mention-suggestions", "not-a-real-token")
        self.assertEqual(status, 401)
        self.assertEqual(body["code"], "invalid_access_token")

    def test_mobile_access_gate_is_enforced(self):
        """Losing group_mobile_user must lock the endpoint out immediately."""
        token = self._token()
        self.user.sudo().write({
            "group_ids": [(3, self.env.ref(
                "odx_mobile_connector.group_mobile_user").id)],
        })
        self.env.flush_all()
        status, body = self._get(
            "/api/mobile/v1/log-note/mention-suggestions", token)
        self.assertEqual(status, 403)
        self.assertEqual(body["code"], "mobile_access_denied")

    def test_empty_search_returns_candidates(self):
        """No search key at all => the full list, not an empty one."""
        data = self._suggestions(self._token())
        self.assertTrue(data["suggestions"])
        self.assertEqual(data["search"], "")

    def test_search_filters_by_name(self):
        data = self._suggestions(self._token(), "?search=%s" % self.marker)
        names = [s["name"] for s in data["suggestions"]]
        self.assertEqual(len(names), 3, names)
        self.assertTrue(all(self.marker in name for name in names))

    def test_search_matches_email_as_well_as_name(self):
        data = self._suggestions(
            self._token(), "?search=log_note_contact@test.com")
        ids = [s["id"] for s in data["suggestions"]]
        self.assertIn(self.plain_partner.id, ids)

    def test_search_is_case_insensitive(self):
        data = self._suggestions(
            self._token(), "?search=%s" % self.marker.upper())
        self.assertEqual(len(data["suggestions"]), 3)

    def test_unknown_search_returns_empty_list_not_error(self):
        data = self._suggestions(
            self._token(), "?search=nobodyhasthisnameatall")
        self.assertEqual(data["suggestions"], [])
        self.assertEqual(data["total"], 0)
        self.assertFalse(data["has_more"])

    def test_ordering_matches_odoo_mention_priority(self):
        """Internal user, then portal user, then plain contact, matching the web chatter's mention order."""
        data = self._suggestions(self._token(), "?search=%s" % self.marker)
        ids = [s["id"] for s in data["suggestions"]]
        self.assertEqual(ids, [
            self.internal_partner.id,
            self.portal_partner.id,
            self.plain_partner.id,
        ])

    def test_candidate_set_matches_odoo_chatter_exactly(self):
        """Candidates must match Odoo's own `get_mention_suggestions` ids and order exactly."""
        expected = self.env["res.partner"].with_user(self.user)._search_mention_suggestions(
            self.env["res.partner"]._get_mention_suggestions_domain(self.marker),
            50,
        ).ids
        data = self._suggestions(
            self._token(), "?search=%s&limit=50" % self.marker)
        self.assertEqual([s["id"] for s in data["suggestions"]], expected)

    def test_id_is_the_partner_id_used_to_create_the_log_note(self):
        """`id` must be the res.partner id message_post(partner_ids=) takes."""
        data = self._suggestions(self._token(), "?search=%s" % self.marker)
        entry = data["suggestions"][0]
        self.assertEqual(entry["id"], self.internal_partner.id)
        self.assertNotEqual(entry["id"], self.internal_user.id)
        self.assertEqual(entry["user_id"], self.internal_user.id)

    def test_payload_carries_name_image_and_internal_flag(self):
        data = self._suggestions(self._token(), "?search=%s" % self.marker)
        by_id = {s["id"]: s for s in data["suggestions"]}

        internal = by_id[self.internal_partner.id]
        self.assertEqual(internal["name"], "%s Internal" % self.marker)
        self.assertTrue(internal["is_internal_user"])
        self.assertIn("/api/mobile/v1/partners/%s/avatar?t="
                      % self.internal_partner.id, internal["image_url"])

        self.assertFalse(by_id[self.plain_partner.id]["is_internal_user"])
        self.assertIsNone(by_id[self.plain_partner.id]["user_id"])

    def test_data_is_a_dict_not_a_bare_list(self):
        """`data` must be a dict, consistent with the other endpoints' envelope."""
        _, body = self._get(
            "/api/mobile/v1/log-note/mention-suggestions", self._token())
        self.assertIsInstance(body["data"], dict)

    def test_limit_is_applied_and_has_more_is_reported(self):
        data = self._suggestions(
            self._token(), "?search=%s&limit=2" % self.marker)
        self.assertEqual(len(data["suggestions"]), 2)
        self.assertEqual(data["total"], 2)
        self.assertTrue(data["has_more"])

    def test_has_more_is_false_when_the_list_is_complete(self):
        data = self._suggestions(
            self._token(), "?search=%s&limit=50" % self.marker)
        self.assertFalse(data["has_more"])

    def test_limit_is_capped(self):
        data = self._suggestions(self._token(), "?limit=99999")
        self.assertEqual(data["limit"], 50)

    def test_non_integer_limit_is_a_400(self):
        status, body = self._get(
            "/api/mobile/v1/log-note/mention-suggestions?limit=abc",
            self._token())
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_pagination")

    def test_zero_limit_is_a_400(self):
        status, body = self._get(
            "/api/mobile/v1/log-note/mention-suggestions?limit=0", self._token())
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_pagination")

    def test_signed_avatar_url_loads_without_a_bearer_token(self):
        """The whole point of the signed link: usable in Image.network()."""
        url = self._avatar_url_for(self._token(), self.internal_partner)
        resp = self.url_open(self._path(url))
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.headers["Content-Type"].startswith("image/"))

    def test_tampered_avatar_token_is_rejected(self):
        status, body = self._get(
            "/api/mobile/v1/partners/%s/avatar?t=%x.%s"
            % (self.internal_partner.id, int(time.time()) + 600, "0" * 16))
        self.assertEqual(status, 403)
        self.assertEqual(body["code"], "avatar_token_invalid")

    def test_expired_avatar_token_is_rejected(self):
        """A correctly signed token past its expiry is refused."""
        expired = int(time.time()) - 60
        sig = MobileApiAuth()._sign_image_token(
            self.internal_partner, MENTION_AVATAR_FIELD, expired)
        status, body = self._get(
            "/api/mobile/v1/partners/%s/avatar?t=%x.%s"
            % (self.internal_partner.id, expired, sig))
        self.assertEqual(status, 403)
        self.assertEqual(body["code"], "avatar_token_invalid")

    def test_avatar_token_is_not_transferable_between_records(self):
        """A token minted for one partner must not fetch another's image; the signature covers model and id."""
        url = self._avatar_url_for(self._token(), self.internal_partner)
        stolen = url.split("?t=", 1)[1]
        status, body = self._get(
            "/api/mobile/v1/partners/%s/avatar?t=%s"
            % (self.plain_partner.id, stolen))
        self.assertEqual(status, 403)
        self.assertEqual(body["code"], "avatar_token_invalid")

    def test_non_integer_partner_id_returns_json_not_html(self):
        """The route accepts any string precisely so this stays JSON."""
        status, body = self._get("/api/mobile/v1/partners/not-a-number/avatar")
        self.assertEqual(status, 400)
        self.assertEqual(body["code"], "invalid_partner_id")

    def test_avatar_without_token_requires_authentication(self):
        status, body = self._get(
            "/api/mobile/v1/partners/%s/avatar" % self.internal_partner.id)
        self.assertEqual(status, 401)
        self.assertEqual(body["code"], "missing_access_token")

    def test_oversized_resize_is_clamped(self):
        """Unbounded width/height on an unauthenticated route is a memory
        amplification lever. Must not 500."""
        url = self._avatar_url_for(self._token(), self.internal_partner)
        resp = self.url_open(
            "%s&width=999999&height=999999" % self._path(url))
        self.assertEqual(resp.status_code, 200)
