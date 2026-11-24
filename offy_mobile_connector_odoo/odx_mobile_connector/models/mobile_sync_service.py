import logging

from odoo import models

_logger = logging.getLogger(__name__)

# Bus notification types the Flutter client switches on.
SYNC_TYPE = "mobile_sync"      # "these home sections are stale, refetch them"
ACCESS_TYPE = "mobile_access"  # full permission payload, applied immediately

# Home sections, mirroring the keys under `data.home` in GET /api/mobile/v1/home.
HOME_SECTIONS = {
    "attendance",
    "time_off",
    "expense",
    "payslip",
    "calendar",
    "activities",
    # Home bell dot (`has_unread_notifications`): sent by mobile.notification.log.
    "notifications",
}


class MobileSyncService(models.AbstractModel):
    """Realtime fan-out of permission and home changes to connected devices.
    ``mobile_sync`` only flags stale home sections; ``mobile_access`` inlines the payload so revocation is immediate."""

    _name = "mobile.sync.service"
    _description = "Mobile Realtime Sync Service"

    def _feature_payload(self, user):
        """Active features this user may use (deny-by-default via ``mobile.user.feature``).
        Shared by REST and websocket so they cannot disagree."""
        features = self.env["mobile.feature"].sudo().search(
            [("active", "=", True)], order="sequence, id"
        )
        allowed_ids = set(
            self.env["mobile.user.feature"].sudo().search(
                [("user_id", "=", user.id), ("feature_id", "in", features.ids)]
            ).mapped("feature_id.id")
        )
        result = []
        for feature in features:
            if feature.id not in allowed_ids:
                continue
            gps = None
            if feature.code == "attendance":
                geofence = user.employee_id._mobile_attendance_geofence()
                gps = {
                    "enabled": geofence["enabled"],
                    "checkin_required": geofence["checkin_required"],
                    "checkout_required": geofence["checkout_required"],
                    "company_latitude": geofence["latitude"],
                    "company_longitude": geofence["longitude"],
                    "boundary_meters": geofence["boundary_meters"],
                }
            result.append({
                "code": feature.code,
                "name": feature.name,
                "active": feature.active,
                "gps": gps,
            })
        return result

    def _access_payload(self, user):
        """The ``data`` body of GET /api/mobile/v1/user/access-details.
        The company block uses the default company, so a client that switched company should refetch."""
        config = self.env["mobile.config"].sudo().search([], limit=1)
        company = user.sudo().company_id
        return {
            "user": {
                "id": user.id,
                "name": user.name,
                "login": user.login,
                "active": user.active,
                "mobile_user": user.sudo().has_group(
                    "odx_mobile_connector.group_mobile_user"
                ),
            },
            "company": {
                "default_company_id": company.id,
                "default_company_currency": {
                    "id": company.currency_id.id,
                    "name": company.currency_id.name,
                    "symbol": company.currency_id.symbol,
                },
            },
            "config": {
                "login_enabled": config.login_enabled if config else True,
                "maintenance_mode": config.maintenance_mode if config else False,
                "max_devices": config.max_devices if config else 1,
                "push_notifications_enabled": (
                    config.push_notifications_enabled if config else True
                ),
            },
            "features": self._feature_payload(user),
        }

    def _mobile_users(self, users):
        """Keep users who could have a socket open, deliberately without requiring ``group_mobile_user``,
        so a user whose access was revoked still gets the ``mobile_user: false`` message."""
        return users.sudo().filtered(lambda u: u.active and u.partner_id)

    def notify_home(self, users, sections, reason=False):
        """Tell *users* that the named home sections are stale; unknown names are dropped.
        Never raises, so realtime sync cannot break the triggering transaction."""
        try:
            valid = sorted(set(sections) & HOME_SECTIONS)
            unknown = set(sections) - HOME_SECTIONS
            if unknown:
                _logger.warning(
                    "Ignoring unknown mobile home section(s): %s", sorted(unknown))
            if not valid:
                return
            targets = self._mobile_users(users)
            for user in targets:
                user.partner_id._bus_send(SYNC_TYPE, {
                    "sections": valid,
                    "reason": reason or "",
                })
        except Exception:
            _logger.exception("Failed to send mobile home sync notification.")

    def notify_access(self, users, reason=False):
        """Push the full permission payload to *users* inline, so a revocation applies immediately."""
        try:
            for user in self._mobile_users(users):
                user.partner_id._bus_send(ACCESS_TYPE, {
                    "reason": reason or "",
                    "access": self._access_payload(user),
                })
        except Exception:
            _logger.exception("Failed to send mobile access sync notification.")
