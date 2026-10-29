import base64
import json
import logging
import time

from odoo import _, api, fields, models
from odoo.tools import config as odoo_config

from .mobile_config import FIREBASE_REQUIRED_KEYS
from .mobile_notification_log import MAX_DISPATCH_ATTEMPTS

_logger = logging.getLogger(__name__)

# Process-local OAuth token cache: {client_email: (access_token, expires_at)}.
_ACCESS_TOKEN_CACHE = {}
# Refresh this many seconds before actual expiry, so a token cannot go stale mid-batch.
_TOKEN_EXPIRY_SKEW = 300
_TOKEN_ASSUMED_TTL = 3600

# Cron batch size: big enough to drain a normal day in one tick, small enough to bound a run.
DISPATCH_BATCH_SIZE = 200

FIREBASE_MESSAGING_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_FCM_ENDPOINT = "https://fcm.googleapis.com/v1/projects/%s/messages:send"

# FCM v1 error statuses meaning the token is dead and must never be retried.
PERMANENT_FCM_STATUSES = {
    "UNREGISTERED",
    "NOT_FOUND",
    "INVALID_ARGUMENT",  # assumed token-shape invalid; see _classify_failure
    "SENDER_ID_MISMATCH",
}


class MobilePushService(models.AbstractModel):
    """Business-agnostic Firebase Cloud Messaging (HTTP v1) delivery service.
    ``requests``/``cryptography`` are lazy imports so the module installs without them."""

    _name = "mobile.push.service"
    _description = "Mobile Push Notification Service"

    def send_to_user(self, user, title, body, data=None):
        """Send one notification to every active token of *user*. Never raises.
        Returns ``{"success": True, "data": {...}}`` or ``{"success": False, "error": {"code", "message"}}``."""
        config = self._get_config()
        if not config.push_notifications_enabled:
            return self._error(
                "firebase_disabled",
                _("Push notifications are not enabled."),
            )

        service_account, error = self._read_service_account_from_config(config)
        if error:
            return self._error(
                "firebase_config_missing",
                _("Firebase push notification configuration is incomplete."),
            )

        tokens = self._active_tokens_for_user(user)
        if not tokens:
            # No devices to notify is a success, not an error.
            return self._nothing_to_send()

        try:
            access_token = self._get_access_token(service_account)
        except ImportError:
            return self._error(
                "firebase_unavailable",
                _("Push notification delivery is temporarily unavailable."),
            )
        except Exception:
            _logger.warning("Firebase OAuth token request failed.")
            return self._error(
                "firebase_auth_failed",
                _("Could not authenticate with the push notification service."),
            )

        return self._deliver_to_tokens(
            tokens, service_account, access_token, config, title, body, data)

    @staticmethod
    def _nothing_to_send():
        return {"success": True, "data": {
            "sent": 0, "failed": 0, "skipped": 1, "results": [],
        }}

    def _deliver_to_tokens(self, tokens, service_account, access_token,
                           config, title, body, data):
        """Fan one message out over already-resolved tokens.
        Split out so the dispatch cron can reuse one OAuth token across a batch."""
        endpoint = _FCM_ENDPOINT % service_account["project_id"]
        sent = failed = 0
        results = []
        for token in tokens:
            self._record_send_attempt(token)
            ok, code, message, status_code = self._post_message(
                endpoint, access_token, token.firebase_id, title, body, data
            )
            if ok:
                sent += 1
                self._record_success(token)
            else:
                failed += 1
                # One token's failure must not stop delivery to the remaining tokens.
                self._handle_send_failure(token, config, status_code, code, message)
            results.append({"token_id": token.id, "sent": ok})

        return {"success": True, "data": {
            "sent": sent, "failed": failed, "skipped": 0, "results": results,
        }}

    def send_to_users(self, users, title, body, data=None):
        """Convenience fan-out; aggregates per-user results."""
        aggregate = {"sent": 0, "failed": 0, "skipped": 0, "results": []}
        for user in users:
            outcome = self.send_to_user(user, title, body, data=data)
            if outcome.get("success"):
                payload = outcome["data"]
                aggregate["sent"] += payload["sent"]
                aggregate["failed"] += payload["failed"]
                aggregate["skipped"] += payload["skipped"]
                aggregate["results"].extend(payload["results"])
        return {"success": True, "data": aggregate}

    def send_once_to_user(self, user, notification_type, res_model, res_id, title, body, data=None):
        """Like ``send_to_user``, but de-duplicated per (user, type, res_model, res_id) and logged.
        Only a prior ``sent`` row suppresses; failed/skipped rows may retry. Never raises."""
        # sudo(): the dedup log has no ACL for group_mobile_user or server-side callers.
        Log = self.env["mobile.notification.log"].sudo()
        already_sent = Log.search_count([
            ("user_id", "=", user.id),
            ("notification_type", "=", notification_type),
            ("res_model", "=", res_model),
            ("res_id", "=", res_id),
            ("status", "=", "sent"),
        ])
        if already_sent:
            return {"success": True, "data": {"skipped": True, "reason": "already_sent"}}

        try:
            result = self.send_to_user(user, title, body, data=data)
        except Exception:
            _logger.exception(
                "Unexpected error sending push notification (type=%s, model=%s, id=%s).",
                notification_type, res_model, res_id,
            )
            result = self._error("unexpected_error", _("Could not send the notification."))

        status, delivery_message = self._classify_log_status(result)
        Log.create({
            "user_id": user.id,
            "notification_type": notification_type,
            "res_model": res_model,
            "res_id": res_id,
            "status": status,
            "title": title,
            "message": body,
            "data_json": json.dumps(data or {}, default=str),
            "delivery_message": delivery_message,
        })
        return result

    def queue_once_to_user(self, user, notification_type, res_model, res_id,
                           title, body, data=None, dedup_key=None):
        """Queue one de-duplicated notification and wake the dispatch cron after commit. Never raises.
        No HTTP in the caller's transaction; ``dedup_key`` lets repeated events on one record each notify."""
        # sudo(): the log has no ACL for group_mobile_user or server-side callers.
        Log = self.env["mobile.notification.log"].sudo()
        try:
            existing = Log.search_count([
                ("user_id", "=", user.id),
                ("notification_type", "=", notification_type),
                ("res_model", "=", res_model),
                ("res_id", "=", res_id),
                ("dedup_key", "=", dedup_key or False),
                ("status", "in", ("sent", "pending")),
            ])
            if existing:
                return {"success": True, "data": {
                    "queued": False, "reason": "already_queued_or_sent"}}

            Log.create({
                "user_id": user.id,
                "notification_type": notification_type,
                "res_model": res_model,
                "res_id": res_id,
                "status": "pending",
                "title": title,
                "message": body,
                "data_json": json.dumps(data or {}, default=str),
                "dedup_key": dedup_key or False,
            })
            self._request_immediate_dispatch()
        except Exception:
            _logger.exception(
                "Could not queue push notification (type=%s, model=%s, id=%s).",
                notification_type, res_model, res_id,
            )
            return self._error("queue_failed", _("Could not queue the notification."))
        return {"success": True, "data": {"queued": True}}

    def _request_immediate_dispatch(self):
        """Trigger the dispatch cron to run right after this transaction commits, once per transaction.
        Uses ``ir.cron._trigger()`` (postcommit notify); failures are swallowed so the business write survives."""
        try:
            if self.env.cr.precommit.data.get("mobile_push_dispatch_triggered"):
                return
            cron = self.env.ref(
                "odx_mobile_connector.ir_cron_dispatch_push_notifications",
                raise_if_not_found=False,
            )
            if not cron:
                return
            self.env.cr.precommit.data["mobile_push_dispatch_triggered"] = True
            cron.sudo()._trigger()
        except Exception:
            _logger.warning(
                "Could not trigger immediate push dispatch; the notification "
                "stays queued for the next scheduled run.", exc_info=True,
            )

    @api.model
    def _cron_dispatch_pending(self, batch_size=DISPATCH_BATCH_SIZE):
        """Deliver queued notifications to Firebase with one OAuth token per batch (ir.cron).
        No-device rows are skipped; temporary failures retry up to ``MAX_DISPATCH_ATTEMPTS``."""
        Log = self.env["mobile.notification.log"].sudo()
        pending = Log.search(
            [("status", "=", "pending")], order="sent_at asc, id asc",
            limit=batch_size,
        )
        if not pending:
            return 0

        config = self._get_config()
        if not config.push_notifications_enabled:
            # Leave the rows pending: they go out if push is switched back on.
            _logger.info(
                "Push disabled; %s queued notification(s) left pending.",
                len(pending))
            return 0

        service_account, error = self._read_service_account_from_config(config)
        if error:
            _logger.warning(
                "Firebase credentials incomplete; %s notification(s) left "
                "pending.", len(pending))
            return 0

        try:
            access_token = self._get_access_token(service_account)
        except ImportError:
            _logger.warning(
                "requests/cryptography unavailable; %s notification(s) left "
                "pending.", len(pending))
            return 0
        except Exception:
            _logger.warning(
                "Firebase OAuth failed; %s notification(s) left pending.",
                len(pending))
            return 0

        for log in pending:
            try:
                self._dispatch_one(log, config, service_account, access_token)
            except Exception:
                # One poisoned row must never stall the queue behind it.
                _logger.exception(
                    "Unexpected error dispatching notification %s.", log.id)
                self._mark_attempt(log, "All token deliveries failed.")

        if len(pending) >= batch_size:
            self._request_immediate_dispatch()
        return len(pending)

    def _dispatch_one(self, log, config, service_account, access_token):
        """Deliver a single queued row and record the outcome on it."""
        data = {}
        if log.data_json:
            try:
                data = json.loads(log.data_json)
            except ValueError:
                _logger.warning(
                    "Notification %s has unreadable data_json; sending without "
                    "a data payload.", log.id)

        tokens = self._active_tokens_for_user(log.user_id)
        if not tokens:
            # No device will appear by retrying, so close the row as skipped.
            log.write({
                "status": "skipped",
                "delivery_message": "No active device tokens.",
                "attempt_count": log.attempt_count + 1,
                "last_attempt_at": fields.Datetime.now(),
            })
            return

        result = self._deliver_to_tokens(
            tokens, service_account, access_token, config,
            log.title, log.message, data,
        )
        if result.get("success") and result["data"].get("sent"):
            log.write({
                "status": "sent",
                "delivery_message": False,
                "attempt_count": log.attempt_count + 1,
                "last_attempt_at": fields.Datetime.now(),
            })
            return
        self._mark_attempt(log, "All token deliveries failed.")

    @staticmethod
    def _mark_attempt(log, message):
        """Record a failed attempt, parking the row once retries run out."""
        attempts = log.attempt_count + 1
        log.write({
            "status": "failed" if attempts >= MAX_DISPATCH_ATTEMPTS else "pending",
            "delivery_message": message,
            "attempt_count": attempts,
            "last_attempt_at": fields.Datetime.now(),
        })

    @staticmethod
    def _classify_log_status(result):
        if not result.get("success"):
            # Config-level non-send (disabled/misconfigured/auth failure) is skipped, not failed.
            return "skipped", result["error"]["message"]
        payload = result["data"]
        if payload.get("skipped"):
            return "skipped", "No active device tokens."
        if payload.get("sent"):
            return "sent", False
        return "failed", "All token deliveries failed."

    def _get_config(self):
        # sudo(): server-side delivery must read the admin-only Firebase credentials.
        return self.env["mobile.config"].sudo().get_config()

    def _read_service_account_from_config(self, config):
        data, error = config._decode_service_account(
            config.firebase_service_account_file
        )
        if error:
            return None, error
        missing = [key for key in FIREBASE_REQUIRED_KEYS if not data.get(key)]
        if missing:
            return None, _("Service account JSON is missing required keys.")
        return data, None

    def _active_tokens_for_user(self, user):
        # sudo(): group_mobile_user and server automation have no ACL on device tokens.
        return self.env["mobile.device.token"].sudo().search([
            ("session_id.user_id", "=", user.id),
            ("active", "=", True),
        ])

    def _record_send_attempt(self, token):
        # sudo(): same ACL reason as _active_tokens_for_user.
        token.sudo().write({"last_push_sent_at": fields.Datetime.now()})

    def _record_success(self, token):
        """A successful send clears any failure streak so old failures never deactivate a healthy token."""
        # sudo(): same ACL reason as _active_tokens_for_user.
        token.sudo().write({
            "failure_count": 0,
            "last_success_at": fields.Datetime.now(),
            "last_failure_code": False,
            "last_failure_message": False,
        })

    def _handle_send_failure(self, token, config, status_code, code, message):
        classification = self._classify_failure(status_code, code)
        if classification == "permanent":
            self._deactivate_token_permanent(token, code, message)
        else:
            self._record_temporary_failure(token, config, code, message)

    @staticmethod
    def _classify_failure(status_code, fcm_status):
        """Return "permanent" (HTTP 404 or PERMANENT_FCM_STATUSES) or "temporary".
        Unknown statuses default to temporary so a recoverable token is never destroyed."""
        if status_code == 404 or fcm_status in PERMANENT_FCM_STATUSES:
            return "permanent"
        return "temporary"

    def _deactivate_token_permanent(self, token, code, message):
        # sudo(): see _active_tokens_for_user.
        token.sudo().write({
            "active": False,
            "removed_reason": "permanent_firebase_failure",
            "removed_at": fields.Datetime.now(),
            "last_failure_code": code,
            "last_failure_message": message,
        })

    def _record_temporary_failure(self, token, config, code, message):
        """Increment the failure streak, resetting it if the previous failure fell outside the window."""
        now = fields.Datetime.now()
        window_hours = config.firebase_token_failure_window_hours or 72
        stale = bool(
            token.last_failure_at
            and (now - token.last_failure_at).total_seconds() > window_hours * 3600
        )
        new_count = 1 if (stale or not token.last_failure_at) else token.failure_count + 1

        vals = {
            "failure_count": new_count,
            "last_failure_at": now,
            "last_failure_code": code,
            "last_failure_message": message,
        }
        limit = config.firebase_token_failure_limit or 5
        if config.firebase_token_auto_deactivate_failed and new_count >= limit:
            vals.update({
                "active": False,
                "removed_reason": "temporary_failure_threshold",
                "removed_at": now,
            })
        # sudo(): see _active_tokens_for_user.
        token.sudo().write(vals)

    def _post_message(self, endpoint, access_token, device_token, title, body, data):
        """POST one message. Returns ``(ok, fcm_status_or_code, message, http_status_code)``."""
        requests = self._requests()
        message_payload = {
            "token": device_token,
            "notification": {"title": title or "", "body": body or ""},
        }
        if data:
            # FCM v1 requires all data values to be strings.
            message_payload["data"] = {str(k): str(v) for k, v in data.items()}

        try:
            response = requests.post(
                endpoint,
                json={"message": message_payload},
                headers={"Authorization": "Bearer %s" % access_token},
                timeout=10,
            )
        except requests.exceptions.Timeout:
            _logger.warning("FCM delivery timed out.")
            return False, "timeout", "Request to Firebase timed out.", None
        except requests.exceptions.RequestException:
            _logger.warning("FCM delivery failed: network error.")
            return False, "network_error", "Network error while contacting Firebase.", None

        if response.status_code == 200:
            return True, None, None, 200

        fcm_status = None
        fcm_message = None
        try:
            error_payload = (response.json() or {}).get("error", {})
            fcm_status = error_payload.get("status")
            fcm_message = error_payload.get("message")
        except Exception:
            pass
        # Log only non-sensitive diagnostics: never the credentials or token.
        _logger.warning(
            "FCM delivery failed (http=%s, status=%s).",
            response.status_code, fcm_status,
        )
        return False, fcm_status, fcm_message, response.status_code

    def _get_access_token(self, service_account):
        """Cached wrapper around ``_fetch_access_token``, refreshed ``_TOKEN_EXPIRY_SKEW`` early.
        Bypassed under the test runner so mocked tokens never leak between tests."""
        if odoo_config["test_enable"]:
            return self._fetch_access_token(service_account)

        cache_key = service_account.get("client_email")
        cached = _ACCESS_TOKEN_CACHE.get(cache_key)
        now = time.time()
        if cached and cached[1] > now:
            return cached[0]

        access_token = self._fetch_access_token(service_account)
        _ACCESS_TOKEN_CACHE[cache_key] = (
            access_token, now + _TOKEN_ASSUMED_TTL - _TOKEN_EXPIRY_SKEW,
        )
        return access_token

    def _fetch_access_token(self, service_account):
        """Mint a short-lived OAuth2 access token for FCM HTTP v1.
        Signs the RS256 JWT with ``cryptography``; no google-auth or PyJWT dependency."""
        requests = self._requests()
        assertion = self._build_signed_jwt(service_account)
        response = requests.post(
            service_account["token_uri"],
            data={
                "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                "assertion": assertion,
            },
            timeout=10,
        )
        response.raise_for_status()
        access_token = (response.json() or {}).get("access_token")
        if not access_token:
            raise ValueError("No access_token in Google token response")
        return access_token

    def _build_signed_jwt(self, service_account):
        now = int(time.time())
        header = {"alg": "RS256", "typ": "JWT"}
        claims = {
            "iss": service_account["client_email"],
            "scope": FIREBASE_MESSAGING_SCOPE,
            "aud": service_account["token_uri"],
            "iat": now,
            "exp": now + 3600,
        }
        signing_input = b".".join([
            self._b64url(json.dumps(header).encode("utf-8")),
            self._b64url(json.dumps(claims).encode("utf-8")),
        ])
        signature = self._sign_rs256(service_account["private_key"], signing_input)
        return (signing_input + b"." + self._b64url(signature)).decode("ascii")

    def _sign_rs256(self, private_key_pem, message):
        serialization, hashes, padding = self._crypto()
        private_key = serialization.load_pem_private_key(
            private_key_pem.encode("utf-8"), password=None
        )
        return private_key.sign(message, padding.PKCS1v15(), hashes.SHA256())

    @staticmethod
    def _requests():
        import requests  # noqa: PLC0415 - lazy so the module always installs
        return requests

    @staticmethod
    def _crypto():
        from cryptography.hazmat.primitives import hashes, serialization  # noqa: PLC0415
        from cryptography.hazmat.primitives.asymmetric import padding  # noqa: PLC0415
        return serialization, hashes, padding

    @staticmethod
    def _b64url(data):
        return base64.urlsafe_b64encode(data).rstrip(b"=")

    @staticmethod
    def _error(code, message):
        return {"success": False, "error": {"code": code, "message": message}}
