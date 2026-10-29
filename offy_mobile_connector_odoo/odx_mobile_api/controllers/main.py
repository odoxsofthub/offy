import json
import logging
import time
from datetime import timedelta
from decimal import ROUND_HALF_UP, Decimal, InvalidOperation

import pytz

from odoo import fields, http
from odoo.exceptions import AccessDenied, AccessError
from odoo.http import request
from odoo.tools import SQL
from odoo.tools.misc import consteq, hmac as odoo_hmac

_logger = logging.getLogger(__name__)

API_KEY_SCOPE = "mobile_api"
API_KEY_INDEX_SIZE = 8  # matches odoo res.users.apikeys INDEX_SIZE
ACCESS_TOKEN_DAYS = 1
REFRESH_TOKEN_DAYS = 30


def amount_2dp(value):
    """Amount as a 2-decimal string (32000.0 -> "32000.00"), rounded half-up away from zero.
    Never "-0.00"; None/False and non-numbers are returned unchanged."""
    if value is None or isinstance(value, bool):
        return value
    try:
        amount = Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    except (InvalidOperation, ValueError, TypeError):
        return value
    if not amount.is_finite():
        return value
    return format(abs(amount) if amount == 0 else amount, "f")


def parse_date(value):
    """Parse a client ISO date; return None if missing or malformed.
    Use instead of `fields.Date.to_date`, which raises ValueError on bad input (HTTP 500)."""
    try:
        return fields.Date.to_date(value)
    except (TypeError, ValueError):
        return None


def parse_bool(value):
    """Parse a boolean from JSON or form input (true/1/yes, false/0/no; case-insensitive).
    Returns None if unrecognised so security-relevant flags can answer 400 instead of guessing."""
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        value = value.strip().lower()
        if value in ("true", "1", "yes"):
            return True
        if value in ("false", "0", "no"):
            return False
        return None
    if value in (0, 1):
        return bool(value)
    return None

IMAGE_TOKEN_SCOPE = "mobile_avatar"
IMAGE_TOKEN_TTL = 24 * 60 * 60  # 1 day
# Hex chars of the HMAC-SHA256 digest actually used in the token.
IMAGE_SIG_LENGTH = 16
# Upper bound on `?width=`/`?height=`.
MAX_IMAGE_DIMENSION = 1920


class MobileApiAuth(http.Controller):
    """Mobile auth endpoints: http, auth='none', CSRF-exempt, JSON.
    Access tokens are API keys (scope `mobile_api`); refresh tokens are hashed and rotated."""

    def _payload(self):
        """Return the request JSON body as a dict (supports a ``params`` wrapper)."""
        try:
            data = request.get_json_data()
        except Exception:
            data = None
        if isinstance(data, dict):
            if isinstance(data.get("params"), dict):
                return data["params"]
            return data
        return {}

    def _json(self, *, success, message, code=None, data=None, status=200):
        """Standard mobile envelope: top-level success, message, optional code, and data ({} if empty)."""
        body = {"success": success, "message": message}
        if not success:
            body["code"] = code or "error"
        body["data"] = data if data is not None else {}
        return request.make_response(
            json.dumps(body, default=str),
            headers=[("Content-Type", "application/json")],
            status=status,
        )

    def _bearer_token(self):
        header = request.httprequest.headers.get("Authorization", "")
        if header[:7].lower() == "bearer ":
            return header[7:].strip()
        return None

    def _refresh_token(self, payload):
        if isinstance(payload, dict):
            token = (payload.get("refreshToken") or "").strip()
            if token:
                return token
        return (request.httprequest.headers.get("X-Refresh-Token") or "").strip() or None

    def _user_payload(self, user):
        return {"id": user.id, "name": user.name, "login": user.login}

    def _record_session(self, uid):
        """Upsert mobile.user.session for *uid* using request headers."""
        platform = request.httprequest.headers.get("X-Platform", "").strip() or False
        app_version = request.httprequest.headers.get("X-App-Version", "").strip() or False
        request.env["mobile.user.session"].sudo()._upsert(uid, platform, app_version)

    def _allocation_rows(self, leave_types, employee, target_date=None):
        """`get_allocation_data` rows for *employee*, filtered to its company.
        Odoo's helper has no company clause, so filter on each row's `info['employee_company']`."""
        if not employee:
            return []
        rows = leave_types.get_allocation_data(employee, target_date).get(employee, [])
        allowed = set(self._allowed_company_ids())
        return [
            row for row in rows
            if row[1].get("employee_company") in allowed
        ]

    def _employment_company_ids(self, user):
        """Companies where *user* has an hr.employee record; delegates to `res.users._mobile_company_ids()`."""
        return user._mobile_company_ids()

    def _allowed_company_ids(self):
        """Companies the current request is scoped to, as set by `_get_company_context`.
        sudo() drops multi-company rules, so filter by hand; use `employee_id.company_id` (hr.attendance has no company_id)."""
        return (request.env.context.get("allowed_company_ids")
                or request.env.company.ids)

    def _get_company_context(self, uid):
        """Company selection for this device session, picked via the `X-Mobile-Session` refresh-token index.
        Clients without the header fall back to the default company, never another device's choice."""
        session_id = (request.httprequest.headers.get(
            "X-Mobile-Session", "") or "").strip()
        rec = request.env["mobile.refresh.token"].sudo().browse()
        if session_id:
            rec = request.env["mobile.refresh.token"].sudo().search([
                ("user_id", "=", uid),
                ("token_index", "=", session_id),
                ("revoked", "=", False),
                ("expires_at", ">=", fields.Datetime.now()),
            ], limit=1)
        user = request.env["res.users"].sudo().browse(uid)
        if rec and rec.selected_company_ids:
            # Drop a stale selection rather than trusting the stored value.
            employed = set(self._employment_company_ids(user))
            selected = [cid for cid in rec.selected_company_ids.ids if cid in employed]
            if selected:
                return selected
        return [user.company_id.id]

    def _employee_timezone_name(self, user):
        """Return `hr.employee.tz` for *user*, or None.
        Read via hr.employee.public: the only employee model a non-HR user has an ACL for (no sudo)."""
        try:
            employee = request.env["hr.employee.public"].search(
                [("user_id", "=", user.id)], limit=1)
            return employee.tz or None
        except AccessError:
            # Portal-tier mobile users have no ACL row for hr.employee.public at all.
            return None

    def _company_timezone_name(self):
        """Return the company working-schedule timezone, or None."""
        try:
            return request.env.company.resource_calendar_id.tz or None
        except AccessError:
            return None

    def _mobile_timezone(self, user=None):
        """Timezone for user-facing times, never None: user tz, then employee tz, then company calendar tz, then UTC.
        `res.users.tz` is empty for users created by API or import, so the fallbacks matter."""
        user = user or request.env.user
        name = user.tz
        if not name:
            name = (self._employee_timezone_name(user)
                    or self._company_timezone_name())
        if not name:
            _logger.warning(
                "No timezone resolved for user %s (res.users.tz, hr.employee.tz "
                "and the company working schedule are all unset); using UTC. "
                "Displayed times will be wrong for any user outside UTC.",
                user.id)
            return pytz.utc
        try:
            return pytz.timezone(name)
        except pytz.UnknownTimeZoneError:
            _logger.warning(
                "Unknown timezone %r for user %s; falling back to UTC.",
                name, user.id)
            return pytz.utc

    def _check_mobile_access(self, user):
        """Enforce connector eligibility & global config. Returns (ok, message)."""
        config = request.env["mobile.config"].sudo().search([], limit=1)
        if config and not config.login_enabled:
            return False, "Mobile login is currently disabled."
        if config and config.maintenance_mode:
            return False, "The mobile app is under maintenance."
        if not user.sudo().has_group("odx_mobile_connector.group_mobile_user"):
            return False, "You are not allowed to use the mobile application."
        return True, ""

    def _has_any_employment(self, user):
        """Whether *user* has at least one active employee record, in any company.
        Not company-scoped: no company is chosen at login. sudo() because plain employees lack hr.employee read ACL."""
        return bool(request.env["hr.employee"].sudo().search_count(
            [("user_id", "=", user.id)]
        ))

    def _mobile_feature_allowed(self, user, code):
        """Whether *user* may use an active mobile feature; a `mobile.user.feature` link grants it in full.
        Deny-by-default. Odoo access rights and record rules still apply on top."""
        feature = request.env["mobile.feature"].sudo().search(
            [("code", "=", code), ("active", "=", True)], limit=1
        )
        if not feature:
            return False
        return bool(request.env["mobile.user.feature"].sudo().search_count(
            [("user_id", "=", user.id), ("feature_id", "=", feature.id)]
        ))

    def _issue_access_token(self, name):
        """Generate an API key for the env user; returns (key, expiry).
        Lifetime is mobile.config.session_timeout (minutes), falling back to ACCESS_TOKEN_DAYS."""
        config = request.env["mobile.config"].sudo().search([], limit=1)
        if config and config.session_timeout > 0:
            lifetime = timedelta(minutes=config.session_timeout)
        else:
            lifetime = timedelta(days=ACCESS_TOKEN_DAYS)
        expires_at = fields.Datetime.now() + lifetime
        key = request.env["res.users.apikeys"]._generate(
            API_KEY_SCOPE, name, expires_at
        )
        return key, expires_at

    def _revoke_access_token(self, uid, token):
        """Delete a single API key by its index prefix (raw column, hence SQL)."""
        if not token:
            return
        table = request.env["res.users.apikeys"].sudo()._table
        request.env.cr.execute(SQL(
            "DELETE FROM %s WHERE user_id = %s AND index = %s "
            "AND (scope IS NULL OR scope = %s)",
            SQL.identifier(table), uid, token[:API_KEY_INDEX_SIZE], API_KEY_SCOPE,
        ))

    def _sign_image_token(self, record, field, expiry):
        """Truncated HMAC-SHA256 over (model, id, field, scope, expiry), keyed by `database.secret`.
        su=True only reads the secret; including the model name stops cross-model replay."""
        return odoo_hmac(
            record.env(su=True), IMAGE_TOKEN_SCOPE,
            (record._name, record.id, field, expiry),
        )[:IMAGE_SIG_LENGTH]

    def _image_link_token(self, record, field, ttl=IMAGE_TOKEN_TTL):
        """Return the ``t`` query-param value authorising one image fetch."""
        expiry = int(time.time()) + ttl
        return "%x.%s" % (expiry, self._sign_image_token(record, field, expiry))

    def _verify_image_token(self, record, field, token):
        """Verify a ``t`` query param produced by `_image_link_token`."""
        try:
            expiry_hex, sig = token.split(".", 1)
            expiry = int(expiry_hex, 16)
        except (ValueError, AttributeError):
            return False
        if time.time() >= expiry:
            return False
        return consteq(sig, self._sign_image_token(record, field, expiry))

    def _authenticate_mobile(self, with_company_context=True):
        """Shared auth chain: Bearer token, API-key check, `_check_mobile_access`, company context.
        Returns (user, error_response). `user.active` is already enforced by `_check_apikey_credentials`."""
        token = self._bearer_token()
        if not token:
            return None, self._json(success=False, code="missing_access_token",
                                    message="Missing access token", status=401)
        uid = request.env["res.users.apikeys"].sudo()._check_credentials(
            scope=API_KEY_SCOPE, key=token)
        if not uid:
            return None, self._json(success=False, code="invalid_access_token",
                                    message="Invalid access token", status=401)

        request.update_env(user=uid)
        user = request.env.user
        ok, message = self._check_mobile_access(user)
        if not ok:
            return None, self._json(success=False, code="mobile_access_denied",
                                    message=message, status=403)
        if with_company_context:
            request.update_context(
                allowed_company_ids=self._get_company_context(uid))
            # Re-bound after the switch: res.users.employee_id depends on the company context.
            user = request.env.user
        return user, None

    def _api_base_url(self):
        """Host the client actually connected with; `web.base.url` is often wrong for a phone on the LAN."""
        return request.httprequest.host_url.rstrip("/")

    def _parse_existing_attachment_ids(self, payload):
        """Parse `existing_attachments` (JSON string or array): returns (ids, None) or (None, error).
        ids is None when the field is omitted; callers must then keep every existing attachment."""
        if "existing_attachments" not in payload:
            return None, None
        raw = payload.get("existing_attachments")
        if isinstance(raw, str):
            try:
                raw = json.loads(raw)
            except (TypeError, ValueError):
                return None, self._json(
                    success=False, code="invalid_existing_attachments",
                    message="existing_attachments must be a valid JSON array.",
                    status=400)
        if not isinstance(raw, list):
            return None, self._json(
                success=False, code="invalid_existing_attachments",
                message="existing_attachments must be an array.", status=400)
        try:
            return [int(item) for item in raw], None
        except (TypeError, ValueError):
            return None, self._json(
                success=False, code="invalid_existing_attachments",
                message="existing_attachments must be an array of integer ids.",
                status=400)

    def _record_own_attachments(self, record):
        """Attachments owned by the record itself, excluding any carried by a `mail.message` on it.
        Single definition so what clients see and what writes may touch stay identical. Pass sudo() to bypass rules."""
        return record.attachment_ids - record.message_ids.attachment_ids

    def _image_stream_response(self, record, field, query=None,
                               not_found_code="image_not_found",
                               not_found_message="No image is available."):
        """Stream an image field through `ir.binary` (mimetype, ETag and resizing for free).
        `query` is explicit to avoid kwarg collisions; width/height are clamped to MAX_IMAGE_DIMENSION."""
        query = query or {}
        try:
            width = int(query.get("width", 0) or 0)
            height = int(query.get("height", 0) or 0)
        except (TypeError, ValueError):
            width = height = 0
        width = max(0, min(width, MAX_IMAGE_DIMENSION))
        height = max(0, min(height, MAX_IMAGE_DIMENSION))
        try:
            stream = request.env["ir.binary"]._get_image_stream_from(
                record, field, width=width, height=height,
            )
        except (AccessError, FileNotFoundError):
            return self._json(success=False, code=not_found_code,
                              message=not_found_message, status=404)
        stream.public = True
        return stream.get_response()

    @http.route("/api/mobile/v1/auth/login", type="http", auth="none",
                methods=["POST"], csrf=False, readonly=False)
    def login(self, **kwargs):
        payload = self._payload()
        login = payload.get("login") or payload.get("username")
        password = payload.get("password")
        if not login or not password:
            return self._json(success=False, code="missing_credentials",
                              message="login and password are required", status=400)
        try:
            credential = {"login": login, "password": password, "type": "password"}
            auth_info = request.session.authenticate(request.env, credential)
            uid = auth_info.get("uid")
            if not uid:
                raise AccessDenied()
        except AccessDenied:
            return self._json(success=False, code="invalid_credentials",
                              message="Invalid credentials", status=401)
        except Exception:
            return self._json(success=False, code="server_error",
                              message="Login failed due to a server error.",
                              status=500)

        request.update_env(user=uid)
        user = request.env.user
        ok, message = self._check_mobile_access(user)
        if not ok:
            request.session.logout(keep_db=True)
            return self._json(success=False, code="mobile_access_denied",
                              message=message, status=403)

        # Refuse at the gate rather than letting the app in to a dead end.
        if not self._has_any_employment(user):
            request.session.logout(keep_db=True)
            return self._json(
                success=False, code="employee_not_linked",
                message="No employee is linked to this mobile user.",
                status=403)

        # Enforce max_devices: revoke oldest sessions if limit is exceeded.
        refresh_model = request.env["mobile.refresh.token"].sudo()
        config = request.env["mobile.config"].sudo().search([], limit=1)
        max_devices = config.max_devices if config else 1
        if max_devices > 0:
            active = refresh_model.search([
                ("user_id", "=", uid),
                ("revoked", "=", False),
                ("expires_at", ">=", fields.Datetime.now()),
            ], order="create_date asc")
            overflow = len(active) - (max_devices - 1)
            if overflow > 0:
                active[:overflow].write({"revoked": True, "last_used_at": fields.Datetime.now()})

        token, access_expires = self._issue_access_token("Mobile API - %s" % user.login)
        refresh_token, refresh_rec = refresh_model.issue_token(
            user_id=uid,
            expires_in_days=REFRESH_TOKEN_DAYS,
            user_agent=request.httprequest.headers.get("User-Agent"),
        )
        self._record_session(uid)
        return self._json(success=True, message="Login successful", data={
            "token": token,
            "refreshToken": refresh_token,
            "user": self._user_payload(user),
            "expiresAt": access_expires,
            "refreshExpiresAt": refresh_rec.expires_at,
            "selectedCompanyIds": refresh_rec.selected_company_ids.ids,
            "companySessionId": refresh_rec.token_index,
        })

    @http.route("/api/mobile/v1/auth/logout", type="http", auth="none",
                methods=["POST"], csrf=False, readonly=False)
    def logout(self, **kwargs):
        payload = self._payload()
        token = self._bearer_token()
        if not token:
            return self._json(success=False, code="missing_access_token",
                              message="Missing access token", status=401)
        uid = request.env["res.users.apikeys"].sudo()._check_credentials(
            scope=API_KEY_SCOPE, key=token
        )
        if not uid:
            return self._json(success=False, code="invalid_access_token",
                              message="Invalid access token", status=401)
        request.update_env(user=uid)
        self._revoke_access_token(uid, token)
        refresh_token = self._refresh_token(payload)
        if refresh_token:
            request.env["mobile.refresh.token"].sudo().revoke_token(refresh_token, user_id=uid)

        # Stop pushing to the device that just signed out.
        deactivated = request.env["mobile.device.token"].deactivate_on_logout(
            request.env.user, payload.get("firebase_id"))

        request.session.logout(keep_db=True)
        return self._json(success=True, message="Logout successful", data={
            "push_tokens_cleared": len(deactivated),
        })

    @http.route("/api/mobile/v1/auth/refresh", type="http", auth="none",
                methods=["POST"], csrf=False, readonly=False)
    def refresh(self, **kwargs):
        payload = self._payload()
        refresh_token = self._refresh_token(payload)
        if not refresh_token:
            return self._json(success=False, code="missing_refresh_token",
                              message="Missing refresh token", status=401)
        refresh_model = request.env["mobile.refresh.token"].sudo()
        rec = refresh_model.validate_token(refresh_token)
        if not rec:
            return self._json(success=False, code="invalid_refresh_token",
                              message="Invalid or expired refresh token", status=401)

        rec.write({"revoked": True, "last_used_at": fields.Datetime.now()})
        uid = rec.user_id.id
        request.update_env(user=uid)
        user = request.env.user
        ok, message = self._check_mobile_access(user)
        if not ok:
            return self._json(success=False, code="mobile_access_denied",
                              message=message, status=403)

        # Same gate as login: refresh is the other way a session is renewed.
        if not self._has_any_employment(user):
            return self._json(
                success=False, code="employee_not_linked",
                message="No employee is linked to this mobile user.",
                status=403)

        self._revoke_access_token(uid, self._bearer_token())
        token, access_expires = self._issue_access_token("Mobile API - %s" % user.login)
        new_refresh, new_rec = refresh_model.issue_token(
            user_id=uid,
            expires_in_days=REFRESH_TOKEN_DAYS,
            user_agent=request.httprequest.headers.get("User-Agent"),
            selected_company_ids=rec.selected_company_ids.ids,
        )
        self._record_session(uid)
        return self._json(success=True, message="Token refreshed", data={
            "token": token,
            "refreshToken": new_refresh,
            "user": self._user_payload(user),
            "expiresAt": access_expires,
            "refreshExpiresAt": new_rec.expires_at,
            "selectedCompanyIds": new_rec.selected_company_ids.ids,
            "companySessionId": new_rec.token_index,
        })

    @http.route("/api/mobile/v1/auth/company", type="http", auth="none",
                methods=["PATCH"], csrf=False, readonly=False)
    def update_company(self, **kwargs):
        payload = self._payload()

        token = self._bearer_token()
        if not token:
            return self._json(success=False, code="missing_access_token",
                              message="Missing access token", status=401)
        uid = request.env["res.users.apikeys"].sudo()._check_credentials(
            scope=API_KEY_SCOPE, key=token
        )
        if not uid:
            return self._json(success=False, code="invalid_access_token",
                              message="Invalid access token", status=401)

        refresh_token_str = self._refresh_token(payload)
        if not refresh_token_str:
            return self._json(success=False, code="missing_refresh_token",
                              message="refreshToken is required", status=400)
        refresh_model = request.env["mobile.refresh.token"].sudo()
        rec = refresh_model.validate_token(refresh_token_str)
        if not rec or rec.user_id.id != uid:
            return self._json(success=False, code="invalid_refresh_token",
                              message="Invalid or expired refresh token", status=401)

        request.update_env(user=uid)
        user = request.env.user

        raw = payload.get("companyIds", [])
        if not isinstance(raw, list) or not raw:
            return self._json(success=False, code="invalid_company_ids",
                              message="companyIds must be a non-empty list of integers",
                              status=400)
        try:
            company_ids = [int(c) for c in raw]
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_company_ids",
                              message="companyIds must be a list of integers", status=400)

        # Employment, not just login permission -- see _employment_company_ids.
        allowed_ids = self._employment_company_ids(user)
        invalid = [c for c in company_ids if c not in allowed_ids]
        if invalid:
            return self._json(success=False, code="company_not_allowed",
                              message="You have no employee record in company %s, "
                                      "so it cannot be selected." % invalid,
                              status=403)

        self._revoke_access_token(uid, token)
        rec.write({"revoked": True, "last_used_at": fields.Datetime.now()})

        new_token, access_expires = self._issue_access_token("Mobile API - %s" % user.login)
        new_refresh, new_rec = refresh_model.issue_token(
            user_id=uid,
            expires_in_days=REFRESH_TOKEN_DAYS,
            user_agent=request.httprequest.headers.get("User-Agent"),
            selected_company_ids=company_ids,
        )
        return self._json(success=True, message="Companies updated", data={
            "token": new_token,
            "refreshToken": new_refresh,
            "expiresAt": access_expires,
            "refreshExpiresAt": new_rec.expires_at,
            "selectedCompanyIds": company_ids,
            "companySessionId": new_rec.token_index,
        })

