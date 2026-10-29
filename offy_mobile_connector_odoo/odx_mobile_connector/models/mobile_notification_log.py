from odoo import api, fields, models

STATUSES = [
    ("pending", "Pending"),
    ("sent", "Sent"),
    ("failed", "Failed"),
    ("skipped", "Skipped"),
]

# A pending row is retried by the dispatch cron until this many attempts have been made.
MAX_DISPATCH_ATTEMPTS = 5


class MobileNotificationLog(models.Model):
    """Generic push-notification audit/dedup log that also backs the mobile in-app inbox.
    No SQL unique constraint: only sent/pending rows suppress a resend, so skipped/failed can retry."""

    _name = "mobile.notification.log"
    _description = "Mobile Push Notification Log"
    _order = "sent_at desc"

    user_id = fields.Many2one(
        "res.users", string="User", required=True, index=True, ondelete="cascade"
    )
    notification_type = fields.Char(string="Notification Type", required=True, index=True)
    res_model = fields.Char(string="Related Model", required=True, index=True)
    res_id = fields.Integer(string="Related Record ID", required=True, index=True)
    status = fields.Selection(STATUSES, string="Status", required=True)
    title = fields.Char(string="Title")
    message = fields.Char(string="Message")
    data_json = fields.Text(string="Data JSON")
    dedup_key = fields.Char(
        string="Dedup Key", index=True,
        help="Optional discriminator for events that repeat on the SAME "
             "record. The default dedup identity is "
             "(user, type, res_model, res_id), which is right for a milestone "
             "that happens once -- an expense is approved once. It is wrong "
             "for a recurring event: an expense reimbursed in three "
             "instalments is three notifications about one hr.expense row, "
             "and without a discriminator only the first survives. Triggers "
             "for such events pass the id of the thing that recurs (e.g. "
             "'expense:205:payment:31'); leaving it empty preserves the "
             "once-per-record behaviour.",
    )
    delivery_message = fields.Char(string="Delivery Message")
    read_at = fields.Datetime(string="Read At", index=True)
    sent_at = fields.Datetime(string="Logged At", default=fields.Datetime.now, required=True)
    attempt_count = fields.Integer(
        string="Delivery Attempts", default=0,
        help="Number of times the dispatch cron has tried to deliver this "
             "notification to Firebase.",
    )
    last_attempt_at = fields.Datetime(string="Last Attempt At")

    @api.model_create_multi
    def create(self, vals_list):
        logs = super().create(vals_list)
        logs._sync_mobile_unread("notification_created")
        return logs

    def write(self, vals):
        res = super().write(vals)
        if "read_at" in vals:
            self._sync_mobile_unread("notification_read")
        return res

    def _sync_mobile_unread(self, reason):
        """Realtime refresh of the home bell dot on the owners' devices (never raises)."""
        self.env["mobile.sync.service"].notify_home(
            self.mapped("user_id"), ["notifications"], reason=reason)
