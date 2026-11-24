from odoo.modules.neutralize import get_neutralization_queries
from odoo.tests import TransactionCase, tagged

from .push_common import encode_service_account, make_service_account

MODULE = "odx_mobile_connector"

#: mobile.config fields holding the Google credential or identifying the Firebase project.
CREDENTIAL_FIELDS = {
    "firebase_service_account_file",
    "firebase_service_account_filename",
    "firebase_project_id",
    "firebase_client_email",
    "firebase_token_uri",
    "firebase_validation_status",
    "firebase_validation_message",
    "firebase_last_validation_date",
}

#: firebase_* delivery-tuning fields, not secrets, so neutralize leaves them untouched.
NON_SENSITIVE_SETTINGS = {
    "firebase_token_failure_limit",
    "firebase_token_failure_window_hours",
    "firebase_token_auto_deactivate_failed",
}


@tagged("post_install", "-at_install")
class TestNeutralize(TransactionCase):
    """`data/neutralize.sql` must strip every credential this module stores, including the Firebase key and push targets."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.config = cls.env["mobile.config"].sudo().get_config()
        cls.queries = list(get_neutralization_queries([MODULE]))


    def test_neutralize_sql_is_discovered(self):
        """odoo-bin neutralize finds the file by convention, not by manifest."""
        self.assertEqual(
            len(self.queries), 1,
            "expected exactly one neutralize.sql for %s" % MODULE)
        self.assertTrue(self.queries[0].strip(), "neutralize.sql is empty")

    def test_neutralize_sql_is_not_a_manifest_data_file(self):
        """Neutralize must run only on demand; listing it as manifest data would wipe live credentials on upgrade."""
        manifest = self.env["ir.module.module"].get_module_info(MODULE)
        self.assertNotIn("data/neutralize.sql", manifest.get("data", []))


    def _run_neutralize(self):
        for query in self.queries:
            self.env.cr.execute(query)
        self.env.invalidate_all()

    def test_clears_firebase_credentials(self):
        self.config.write({
            "firebase_service_account_file": encode_service_account(
                make_service_account()),
        })
        self.env.flush_all()
        self.assertTrue(self.config.firebase_service_account_file)

        self._run_neutralize()

        self.assertFalse(self.config.firebase_service_account_file)
        self.assertFalse(self.config.firebase_project_id)
        self.assertFalse(self.config.firebase_client_email)
        self.assertFalse(self.config.firebase_token_uri)
        self.assertFalse(self.config.firebase_validation_status)

    def test_leaves_config_record_valid(self):
        """Push must be disabled in the same statement as the credential, or `_check_firebase_credentials_present` raises later."""
        self.config.write({
            "firebase_service_account_file": encode_service_account(
                make_service_account()),
            "push_notifications_enabled": True,
        })
        self.env.flush_all()

        self._run_neutralize()

        self.assertFalse(self.config.push_notifications_enabled)
        # Would raise ValidationError if the two fields disagreed.
        self.config._check_firebase_credentials_present()

    def test_purges_device_tokens_sessions_and_tickets(self):
        # Dedicated user, since mobile.user.session is unique per user and existing users may have one.
        user = self.env["res.users"].sudo().create({
            "name": "Neutralize Fixture",
            "login": "neutralize_fixture@test.com",
            "group_ids": [(4, self.env.ref("base.group_user").id)],
        })
        session = self.env["mobile.user.session"].sudo().create({
            "user_id": user.id,
        })
        self.env["mobile.device.token"].sudo().create({
            "session_id": session.id,
            "user_id": user.id,
            "firebase_id": "test-fcm-registration-token",
        })
        self.env["mobile.notification.log"].sudo().create({
            "user_id": user.id,
            "notification_type": "test",
            "res_model": "res.users",
            "res_id": user.id,
            # 'pending' on purpose: a queued row would be delivered by the dispatch cron on a restored copy.
            "status": "pending",
            "title": "Payslip for Jane Smith",
            "message": "contains a real name",
        })
        self.env.flush_all()

        self._run_neutralize()

        for model in ("mobile.device.token", "mobile.user.session",
                      "mobile.realtime.ticket", "mobile.notification.log"):
            self.assertFalse(
                self.env[model].sudo().search_count([]),
                "%s survived neutralization" % model)


    def test_every_credential_field_is_covered(self):
        """The credential fields must all appear in the scrub."""
        sql = self.queries[0]
        uncovered = sorted(f for f in CREDENTIAL_FIELDS if f not in sql)
        self.assertFalse(
            uncovered,
            "these credential fields are not cleared by neutralize.sql: %s"
            % ", ".join(uncovered))

    def test_new_firebase_fields_must_be_classified(self):
        """A new firebase_* field must be classified as credential or setting, so it cannot silently escape the scrub."""
        classified = CREDENTIAL_FIELDS | NON_SENSITIVE_SETTINGS
        unclassified = sorted(
            name for name in self.env["mobile.config"]._fields
            if name.startswith("firebase_") and name not in classified)
        self.assertFalse(
            unclassified,
            "new firebase_* field(s) on mobile.config are not classified in "
            "%s: %s -- add each to CREDENTIAL_FIELDS (and to neutralize.sql) "
            "or to NON_SENSITIVE_SETTINGS."
            % (__name__, ", ".join(unclassified)))
