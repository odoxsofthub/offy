import base64
import json

from odoo import _, api, fields, models
from odoo.exceptions import ValidationError
from odoo.tools import config

# Shared bounds for every attendance geofence radius, including the company fallback fence.
GPS_BOUNDARY_MIN = 50
GPS_BOUNDARY_MAX = 5000

# Keys a Google service-account JSON must contain to be usable for Firebase.
FIREBASE_REQUIRED_KEYS = (
    "type",
    "project_id",
    "private_key_id",
    "private_key",
    "client_email",
    "token_uri",
)

# Firebase credential fields are readable only by the Mobile Administrator group.
_ADMIN_GROUP = "odx_mobile_connector.group_mobile_admin"


class MobileConfig(models.Model):
    """Singleton global configuration for the mobile app; ``get_config`` guarantees one exists.
    Also holds the Firebase (FCM HTTP v1) service-account credentials used by ``mobile.push.service``."""

    _name = "mobile.config"
    _description = "Mobile Configuration"
    _inherit = ["mail.thread"]

    def _compute_display_name(self):
        for record in self:
            record.display_name = _("Mobile Configuration")


    login_enabled = fields.Boolean(string="Login Enabled", default=True, tracking=True)
    maintenance_mode = fields.Boolean(string="Maintenance Mode", tracking=True)
    session_timeout = fields.Integer(
        string="Session Timeout (minutes)",
        default=60,
        required=True,
        tracking=True,
        help="Idle time in minutes after which a mobile session expires.",
    )
    max_devices = fields.Integer(
        string="Maximum Devices",
        default=1,
        tracking=True,
        help="Maximum number of concurrent sessions allowed per user. Set to 0 for unlimited.",
    )
    attendance_gps_required = fields.Boolean(
        string="Attendance GPS Required",
        help="Master switch. If enabled, the user must turn on GPS/location "
             "on their device to check in or check out from the mobile app.",
    )
    attendance_checkin_gps_required = fields.Boolean(
        string="Checkin GPS Validation",
        default=True,
        help="If enabled, the mobile user must be inside the attendance "
             "geofence to use the Check-in button.",
    )
    attendance_checkout_gps_required = fields.Boolean(
        string="Checkout GPS Validation",
        default=True,
        help="If enabled, the mobile user must be inside the attendance "
             "geofence to use the Check-out button.",
    )
    attendance_gps_boundary = fields.Integer(
        string="GPS Boundary (Meters)",
        default=GPS_BOUNDARY_MIN,
        help="Radius in meters around the attendance coordinates within which "
             "check-in/check-out is accepted. Between %s and %s meters."
             % (GPS_BOUNDARY_MIN, GPS_BOUNDARY_MAX),
    )
    company_latitude = fields.Float(
        string="Company Latitude",
        # (10, 7) matches the precision of res.partner.partner_latitude.
        digits=(10, 7),
        help="Fallback geofence centre, used for employees whose work "
             "location has no coordinates of its own.",
    )
    company_longitude = fields.Float(
        string="Company Longitude",
        digits=(10, 7),
        help="Fallback geofence centre, used for employees whose work "
             "location has no coordinates of its own.",
    )
    push_notifications_enabled = fields.Boolean(
        string="Push Notifications Enabled", default=False
    )
    show_chatter = fields.Boolean(
        string="Show Chatter Logs Globally",
        default=False,
    )
    show_chatter_logs = fields.Boolean(
        string="Show Chatter Logs",
        default=False,
    )

    log_notes_enabled = fields.Boolean(
        string="Enable Activity Log",
        default=True,
        help="Record changes to mobile features in each feature's chatter "
             "(log notes & field tracking such as Name, Code, Active).",
    )
    log_user_access_changes = fields.Boolean(
        string="Log User Access Changes",
        default=True,
        help="When the activity log is on, also log on a feature's chatter "
             "whenever a user is granted, removed, or has their Read/Write "
             "access changed for that feature.",
    )

    firebase_service_account_file = fields.Binary(
        string="Service Account JSON",
        # attachment=False keeps the credential inline in the table instead of an ir.attachment.
        attachment=False,
        groups=_ADMIN_GROUP,
        help="Upload the Firebase service account JSON (HTTP v1). Parsed "
             "server-side; the private key is never shown back in the form.",
    )
    firebase_service_account_filename = fields.Char(
        string="Service Account Filename", groups=_ADMIN_GROUP
    )
    firebase_project_id = fields.Char(
        string="Firebase Project ID", readonly=True, groups=_ADMIN_GROUP
    )
    firebase_client_email = fields.Char(
        string="Service Account Client Email", readonly=True, groups=_ADMIN_GROUP
    )
    firebase_token_uri = fields.Char(
        string="Token URI", readonly=True, groups=_ADMIN_GROUP
    )
    firebase_validation_status = fields.Selection(
        [
            ("not_validated", "Not Validated"),
            ("valid", "Valid"),
            ("invalid", "Invalid"),
        ],
        string="Credential Status",
        default="not_validated",
        readonly=True,
        groups=_ADMIN_GROUP,
    )
    firebase_last_validation_date = fields.Datetime(
        string="Last Validated On", readonly=True, groups=_ADMIN_GROUP
    )
    firebase_validation_message = fields.Char(
        string="Validation Message", readonly=True, groups=_ADMIN_GROUP
    )

    # Token failure-cleanup thresholds read by mobile.push.service.
    firebase_token_failure_limit = fields.Integer(
        string="Token Failure Limit",
        default=5,
        groups=_ADMIN_GROUP,
        help="Number of temporary Firebase delivery failures (within the "
             "failure window) after which a device token is deactivated.",
    )
    firebase_token_failure_window_hours = fields.Integer(
        string="Token Failure Window (Hours)",
        default=72,
        groups=_ADMIN_GROUP,
        help="Temporary failures older than this many hours no longer count "
             "toward the failure limit — a token that fails, then succeeds "
             "or goes quiet, is not punished for old, unrelated failures.",
    )
    firebase_token_auto_deactivate_failed = fields.Boolean(
        string="Auto-Deactivate Failed Tokens",
        default=True,
        groups=_ADMIN_GROUP,
        help="When enabled, a token is automatically deactivated once its "
             "temporary-failure count reaches the limit above. When "
             "disabled, failures are still recorded but the token is left "
             "active.",
    )

    @api.constrains(
        "firebase_token_failure_limit", "firebase_token_failure_window_hours")
    def _check_firebase_token_failure_settings(self):
        for record in self:
            if record.firebase_token_failure_limit < 1:
                raise ValidationError(_(
                    "Token Failure Limit must be at least 1."))
            if record.firebase_token_failure_window_hours < 1:
                raise ValidationError(_(
                    "Token Failure Window (Hours) must be at least 1."))

    @api.constrains("attendance_gps_boundary")
    def _check_gps_boundary(self):
        for record in self:
            if not (GPS_BOUNDARY_MIN <= record.attendance_gps_boundary
                    <= GPS_BOUNDARY_MAX):
                raise ValidationError(_(
                    "GPS Boundary must be between %(low)s and %(high)s meters. "
                    "A very large radius silently disables the geofence.",
                    low=GPS_BOUNDARY_MIN, high=GPS_BOUNDARY_MAX))

    @api.constrains(
        "attendance_gps_required",
        "attendance_checkin_gps_required",
        "attendance_checkout_gps_required",
        "company_latitude",
        "company_longitude",
    )
    def _check_company_coordinates(self):
        """Require fallback coordinates once Check-in or Check-out GPS validation is on,
        else employees without work-location coordinates could not check in."""
        for record in self:
            gps_in_effect = record.attendance_gps_required and (
                record.attendance_checkin_gps_required
                or record.attendance_checkout_gps_required
            )
            if gps_in_effect and (
                not record.company_latitude or not record.company_longitude
            ):
                raise ValidationError(_(
                    "Company Latitude and Company Longitude must be set "
                    "(non-zero) when Checkin or Checkout GPS Validation is "
                    "enabled. They are the fallback geofence for employees "
                    "whose work location has no coordinates."
                ))

    @api.constrains("session_timeout")
    def _check_session_timeout(self):
        for record in self:
            if record.session_timeout < 1:
                raise ValidationError(_("Session Timeout (minutes) must be at least 1."))

    @api.model_create_multi
    def create(self, vals_list):
        if self.search_count([]) > 0:
            raise ValidationError(_("Only one mobile configuration record can exist."))
        records = super().create(vals_list)
        if any("firebase_service_account_file" in (vals or {}) for vals in vals_list):
            records._sync_service_account_metadata()
        return records

    # Fields exposed in the `config` block of the mobile access-details payload.
    _MOBILE_VISIBLE_FIELDS = {
        "login_enabled",
        "maintenance_mode",
        "max_devices",
        "push_notifications_enabled",
        "attendance_gps_required",
        "attendance_checkin_gps_required",
        "attendance_checkout_gps_required",
        "attendance_gps_boundary",
        "company_latitude",
        "company_longitude",
    }

    def write(self, vals):
        res = super().write(vals)
        if "firebase_service_account_file" in vals:
            self._sync_service_account_metadata()
        if set(vals) & self._MOBILE_VISIBLE_FIELDS:
            # Global config: every mobile user's payload changed at once.
            group = self.env.ref(
                "odx_mobile_connector.group_mobile_user", raise_if_not_found=False)
            if group:
                self.env["mobile.sync.service"].notify_access(
                    group.sudo().user_ids, reason="mobile_config_changed")
        return res

    def unlink(self):
        raise ValidationError(_("You cannot delete the mobile configuration."))

    @api.model
    def get_config(self):
        """Return the singleton configuration record, creating it if missing."""
        config = self.search([], limit=1)
        if not config:
            config = self.create({})
        return config

    def action_toggle_chatter(self):
        for record in self:
            record.show_chatter_logs = not record.show_chatter_logs

    def _decode_service_account(self, raw):
        """Return ``(data_dict, error_message)`` from a base64 Binary value; never raises or logs the credential."""
        if not raw:
            return None, _("No service account JSON has been uploaded.")
        try:
            content = base64.b64decode(raw)
            data = json.loads(content.decode("utf-8"))
        except Exception:
            # Deliberately generic: do not echo the raw content back.
            return None, _("The uploaded file is not valid JSON.")
        if not isinstance(data, dict):
            return None, _("The uploaded file is not a valid service account object.")
        return data, None

    def _sync_service_account_metadata(self):
        """Refresh the non-secret display fields from the upload.
        Uses ``super().write`` with metadata keys only, so it never re-enters this method."""
        for record in self:
            meta = {
                "firebase_project_id": False,
                "firebase_client_email": False,
                "firebase_token_uri": False,
                "firebase_validation_status": "not_validated",
                "firebase_last_validation_date": False,
                "firebase_validation_message": False,
            }
            raw = record.firebase_service_account_file
            if raw:
                data, error = record._decode_service_account(raw)
                if error:
                    meta["firebase_validation_status"] = "invalid"
                    meta["firebase_validation_message"] = error
                else:
                    meta["firebase_project_id"] = data.get("project_id") or False
                    meta["firebase_client_email"] = data.get("client_email") or False
                    meta["firebase_token_uri"] = data.get("token_uri") or False
            super(MobileConfig, record).write(meta)

    @api.constrains("push_notifications_enabled", "firebase_service_account_file")
    def _check_firebase_credentials_present(self):
        """Require a Firebase service account file whenever push notifications are enabled."""
        for record in self:
            if record.push_notifications_enabled and not record.firebase_service_account_file:
                raise ValidationError(_(
                    "Upload a Firebase service account JSON file before "
                    "enabling Push Notifications."
                ))

    def _store_validation(self, status, message):
        self.write({
            "firebase_validation_status": status,
            "firebase_validation_message": message,
            "firebase_last_validation_date": fields.Datetime.now(),
        })
        # No "reload" client action: it would force a full browser page reload.
        return True

    def action_validate_firebase_credentials(self):
        """Validate the uploaded JSON structurally, then try a live OAuth check outside test mode.
        A live-check failure is only a warning (status stays ``valid``) and does not leak the error."""
        self.ensure_one()
        data, error = self._decode_service_account(self.firebase_service_account_file)
        if error:
            return self._store_validation("invalid", error)

        missing = [key for key in FIREBASE_REQUIRED_KEYS if not data.get(key)]
        if missing:
            return self._store_validation("invalid", _(
                "Service account JSON is missing required keys: %s",
                ", ".join(missing),
            ))

        if config["test_enable"]:
            # Never reach out to Google from the automated test suite.
            return self._store_validation("valid", _(
                "Service account JSON is structurally valid. Live Google "
                "verification is skipped in test mode."
            ))

        try:
            self.env["mobile.push.service"]._fetch_access_token(data)
        except Exception:
            return self._store_validation("valid", _(
                "Service account JSON is structurally valid, but live "
                "verification with Google could not be completed in this "
                "environment. Verify connectivity/credentials in production."
            ))
        return self._store_validation("valid", _(
            "Firebase credentials verified successfully with Google."
        ))

    def action_clear_firebase_credentials(self):
        """Remove the current Firebase JSON so an admin can upload a new one."""
        self.ensure_one()
        self.write({
            "push_notifications_enabled": False,
            "firebase_service_account_file": False,
            "firebase_service_account_filename": False,
        })
        return True
