from odoo.exceptions import ValidationError
from odoo.http import request

from . import main

ALLOWED_DEVICE_TYPES = {"android", "ios", "web", "unknown"}


class MobileApiDeviceToken(main.MobileApiAuth):
    """Firebase/FCM push token registration for the mobile app."""

    @main.http.route("/api/mobile/v1/device-token", type="http", auth="none",
                     methods=["POST"], csrf=False, readonly=False)
    def register_device_token(self, **kwargs):
        user, err = self._authenticate_mobile(with_company_context=False)
        if err:
            return err
        # Re-checked independently of _check_mobile_access.
        if not user.has_group("odx_mobile_connector.group_mobile_user"):
            return self._json(success=False, code="forbidden",
                              message="You are not allowed to use the mobile application.",
                              status=403)

        payload = self._payload()
        firebase_id = (payload.get("firebase_id") or "").strip()
        if not firebase_id:
            return self._json(success=False, code="firebase_id_required",
                              message="Firebase ID is required.", status=400)

        device_type = (payload.get("device_type") or "").strip().lower()
        if device_type not in ALLOWED_DEVICE_TYPES:
            device_type = "unknown"

        try:
            record = request.env["mobile.device.token"].register_token(
                user, firebase_id, device_type
            )
        except ValidationError:
            return self._json(success=False, code="firebase_id_required",
                              message="Firebase ID is required.", status=400)
        except Exception:
            return self._json(success=False, code="server_error",
                              message="Could not register device token.",
                              status=500)

        return self._json(success=True, message="Device token registered successfully.", data={
            "id": record.id,
            "firebase_id": record.firebase_id,
            "device_type": record.device_type,
            "registered_at": record.registered_at,
            "updated_at": record.updated_at,
        })
