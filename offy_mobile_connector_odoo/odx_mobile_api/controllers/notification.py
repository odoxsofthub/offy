import json

from odoo import fields
from odoo.http import request

from . import main
from .home import _iso_utc
from .main import API_KEY_SCOPE
from ..notifications import NOTIFICATION_TITLES, PAYSLIP_AVAILABLE

DEFAULT_LIMIT = 20
MAX_LIMIT = 50

# The inbox and the push triggers share one title table so their wording cannot drift.
TITLE_BY_TYPE = NOTIFICATION_TITLES


class MobileApiNotification(main.MobileApiAuth):
    """Mobile notification inbox."""

    def _authenticate_notification(self):
        token = self._bearer_token()
        if not token:
            return None, self._json(success=False, code="missing_access_token",
                                    message="Missing access token", status=401)
        uid = request.env["res.users.apikeys"].sudo()._check_credentials(
            scope=API_KEY_SCOPE, key=token
        )
        if not uid:
            return None, self._json(success=False, code="invalid_access_token",
                                    message="Invalid access token", status=401)

        request.update_env(user=uid)
        user = request.env.user
        if not user.active:
            return None, self._json(success=False, code="user_inactive",
                                    message="User is inactive", status=403)
        ok, message = self._check_mobile_access(user)
        if not ok:
            return None, self._json(success=False, code="mobile_access_denied",
                                    message=message, status=403)
        request.update_context(
            allowed_company_ids=self._get_company_context(uid))
        return user, None

    @staticmethod
    def _page_params(kwargs):
        try:
            page = int(kwargs.get("page", 1))
            limit = int(kwargs.get("limit", DEFAULT_LIMIT))
        except (TypeError, ValueError):
            return None, None
        if page < 1 or limit < 1:
            return None, None
        return page, min(limit, MAX_LIMIT)

    @staticmethod
    def _decode_data(log):
        if not log.data_json:
            return {}
        try:
            data = json.loads(log.data_json)
        except (TypeError, ValueError):
            return {}
        return data if isinstance(data, dict) else {}

    def _notification_message(self, log, data):
        if log.title and log.message:
            return log.message
        if log.notification_type == PAYSLIP_AVAILABLE and data.get("period"):
            return "Your payslip for %s is now available." % data["period"]
        if log.notification_type == PAYSLIP_AVAILABLE:
            return "Your payslip is now available."
        if log.message:
            return log.message
        return "You have a new notification."

    @staticmethod
    def _notification_company_payload(data):
        """Company block from `data_json` (as it was when raised), or None for rows queued before labelling.
        Not named `_company_payload`: that would shadow profile.py's method through the shared MRO.
        """
        company_id = data.get("company_id")
        if not company_id:
            return None
        return {
            "id": company_id,
            "name": data.get("company_name") or None,
        }

    def _notification_payload(self, log):
        data = self._decode_data(log)
        return {
            "id": log.id,
            "type": log.notification_type,
            "title": log.title or TITLE_BY_TYPE.get(
                log.notification_type, "Notification"),
            "message": self._notification_message(log, data),
            "company": self._notification_company_payload(data),
            "data": data,
            "is_read": bool(log.read_at),
            "read_at": _iso_utc(log.read_at),
            "created_at": _iso_utc(log.sent_at),
            "delivery_status": log.status,
        }

    @main.http.route("/api/mobile/v1/notifications/<int:notification_id>",
                     type="http", auth="none", methods=["DELETE"],
                     csrf=False, readonly=False)
    def notification_delete(self, notification_id, **kwargs):
        """Permanently remove one of the caller's notifications.
        The log model has no mobile ACL, so sudo is needed; the lookup is always constrained to id and current user.
        """
        user, error = self._authenticate_notification()
        if error:
            return error

        notification = request.env["mobile.notification.log"].sudo().search([
            ("id", "=", notification_id),
            ("user_id", "=", user.id),
        ], limit=1)
        if not notification:
            return self._json(success=False, code="notification_not_found",
                              message="Notification not found.", status=404)

        notification.unlink()
        return self._json(success=True,
                          message="Notification deleted successfully.",
                          data={"id": notification_id, "deleted": True})

    @main.http.route("/api/mobile/v1/notifications", type="http", auth="none",
                     methods=["GET"], csrf=False, readonly=False)
    def notification_list(self, **kwargs):
        """List the user's notifications and mark all of them read (intended product behaviour, not just the served page).
        readonly=False is required: auth='none' routes are read-only by default in Odoo 19 and would re-run on write.
        """
        user, error = self._authenticate_notification()
        if error:
            return error

        page, limit = self._page_params(kwargs)
        if page is None:
            return self._json(success=False, code="invalid_pagination",
                              message="page and limit must be positive integers.",
                              status=400)

        # sudo(): mobile users have no direct ACL on mobile.notification.log.
        Log = request.env["mobile.notification.log"].sudo()
        domain = [("user_id", "=", user.id)]
        unread_domain = domain + [("read_at", "=", False)]

        # One search instead of count + search: the rows are needed for the write below.
        unread_logs = Log.search(unread_domain)
        unread_count = len(unread_logs)
        total = Log.search_count(domain)
        notifications = Log.search(
            domain,
            order="sent_at desc, id desc",
            limit=limit,
            offset=(page - 1) * limit,
        )
        # Built BEFORE the write so is_read still reflects the arrival state.
        payload = [self._notification_payload(log) for log in notifications]

        if unread_logs:
            unread_logs.write({"read_at": fields.Datetime.now()})

        return self._json(success=True,
                          message="Notifications fetched successfully",
                          data={
                              "unread_count_before_fetch": unread_count,
                              "notifications": payload,
                              "pagination": {
                                  "page": page,
                                  "limit": limit,
                                  "total": total,
                                  "has_next": page * limit < total,
                              },
                          })
