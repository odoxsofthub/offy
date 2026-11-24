from odoo import api, fields, models


class MobileUserSession(models.Model):
    """Most recent mobile session per user (one upserted row).
    Written only by odx_mobile_api via sudo()."""

    _name = "mobile.user.session"
    _description = "Mobile User Session"
    _order = "last_session desc"
    _rec_name = "user_id"

    user_id = fields.Many2one(
        "res.users",
        string="Employee",
        required=True,
        index=True,
        ondelete="cascade",
    )
    employee_id = fields.Many2one(
        "hr.employee",
        string="Employee Record",
        compute="_compute_employee_id",
        store=True,
    )
    platform = fields.Char(string="Platform")
    app_version = fields.Char(string="App Version")
    first_login = fields.Datetime(string="First Login", readonly=True)
    last_session = fields.Datetime(string="Last Session", readonly=True)
    device_token_ids = fields.One2many(
        "mobile.device.token", "session_id", string="Firebase Device Tokens"
    )
    device_token_count = fields.Integer(
        string="Devices", compute="_compute_device_token_count"
    )
    show_push_tokens = fields.Boolean(
        string="Show Push Tokens",
        compute="_compute_show_push_tokens",
        help="Mirrors mobile.config.push_notifications_enabled, used to "
             "conditionally show the Firebase token list on the form.",
    )

    @api.depends("user_id")
    def _compute_employee_id(self):
        for session in self:
            session.employee_id = self.env["hr.employee"].sudo().search(
                [("user_id", "=", session.user_id.id)], limit=1
            )

    @api.depends("device_token_ids.active")
    def _compute_device_token_count(self):
        for session in self:
            session.device_token_count = len(session.device_token_ids)

    def _compute_show_push_tokens(self):
        show_push_tokens = self.env["mobile.config"].get_config().push_notifications_enabled
        for session in self:
            session.show_push_tokens = show_push_tokens

    _user_unique = models.Constraint(
        "UNIQUE(user_id)",
        "Only one session record per user is allowed.",
    )

    def _upsert(self, uid, platform, app_version):
        """Create or update the session row for *uid*. Called via sudo()."""
        vals = {
            "platform": platform or False,
            "app_version": app_version or False,
            "last_session": fields.Datetime.now(),
        }
        existing = self.search([("user_id", "=", uid)], limit=1)
        if existing:
            existing.write(vals)
        else:
            vals["user_id"] = uid
            vals["first_login"] = vals["last_session"]
            self.create(vals)
