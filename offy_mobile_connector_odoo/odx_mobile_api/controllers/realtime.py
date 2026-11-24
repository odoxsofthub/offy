import logging

from odoo.http import request

from . import main
from .main import API_KEY_SCOPE

_logger = logging.getLogger(__name__)


def _websocket_worker_version():
    """Odoo's expected websocket worker version, or "" if unavailable (Odoo then skips the version check).
    Imported lazily so a bus import failure cannot break loading of every mobile controller.
    """
    try:
        from odoo.addons.bus.websocket import (  # noqa: PLC0415
            WebsocketConnectionHandler,
        )
        return WebsocketConnectionHandler._VERSION
    except Exception:
        _logger.warning(
            "Could not read the Odoo websocket worker version; the mobile "
            "client will connect without a version parameter."
        )
        return ""


class MobileApiRealtime(main.MobileApiAuth):
    """Trades the Bearer token for a short-lived single-use websocket ticket, since /websocket only reads session cookies.
    Never put the long-lived token itself in the query string, which ends up in proxy and access logs.
    """

    @main.http.route("/api/mobile/v1/realtime/ticket", type="http", auth="none",
                     methods=["POST"], csrf=False, readonly=False)
    def realtime_ticket(self, **kwargs):
        """Mint a websocket ticket for the authenticated mobile user."""
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
        user = request.env.user
        if not user.active:
            return self._json(success=False, code="user_inactive",
                              message="User is inactive", status=403)
        ok, message = self._check_mobile_access(user)
        if not ok:
            return self._json(success=False, code="mobile_access_denied",
                              message=message, status=403)

        # sudo(): mobile users have no ACL on the ticket table.
        ticket, expires_in = request.env["mobile.realtime.ticket"].sudo()._issue(user)
        return self._json(
            success=True,
            message="Realtime ticket issued.",
            data={
                "ticket": ticket,
                "expires_in": expires_in,
                # Relative on purpose: the app already knows its own base URL.
                "websocket_path": "/websocket",
                # Odoo closes any websocket whose ?version= does not match its own worker version.
                "websocket_version": _websocket_worker_version(),
            },
        )
