import base64

from odoo.exceptions import AccessError, ValidationError
from odoo.tests import TransactionCase, tagged

from .push_common import encode_service_account, make_service_account


@tagged("post_install", "-at_install")
class TestFirebaseConfig(TransactionCase):
    """Firebase credential fields, parsing, validation and admin-only access."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.config = cls.env["mobile.config"].sudo().get_config()
        cls.valid_sa = make_service_account()
        cls.valid_b64 = encode_service_account(cls.valid_sa)

        cls.admin = cls.env.ref("base.user_admin")  # has group_mobile_admin
        cls.manager = cls.env["res.users"].create({
            "name": "Push Manager",
            "login": "push_manager@test.com",
            "group_ids": [
                (4, cls.env.ref("base.group_user").id),
                (4, cls.env.ref("odx_mobile_connector.group_mobile_manager").id),
            ],
        })

    def test_firebase_fields_exist(self):
        for field in (
            "firebase_service_account_file",
            "firebase_project_id", "firebase_client_email",
            "firebase_token_uri", "firebase_validation_status",
            "firebase_last_validation_date", "firebase_validation_message",
        ):
            self.assertIn(field, self.config._fields, "missing field: %s" % field)
        # No separate "Firebase Enabled" field: push_notifications_enabled is the only switch.
        self.assertNotIn("firebase_enabled", self.config._fields)

    def test_default_push_notifications_disabled_without_credentials(self):
        fresh = self.env["mobile.config"].new({})
        self.assertFalse(
            fresh.push_notifications_enabled,
            "fresh installs must not enable push before Firebase credentials "
            "are uploaded.",
        )

    def test_upload_parses_non_secret_metadata(self):
        self.config.write({
            "firebase_service_account_file": self.valid_b64,
            "firebase_service_account_filename": "sa.json",
        })
        self.assertEqual(self.config.firebase_project_id, "test-project")
        self.assertEqual(
            self.config.firebase_client_email,
            "svc@test-project.iam.gserviceaccount.com",
        )
        self.assertEqual(
            self.config.firebase_token_uri, "https://oauth2.googleapis.com/token")
        # A fresh upload always resets the validation state.
        self.assertEqual(self.config.firebase_validation_status, "not_validated")

    def test_invalid_json_is_rejected_safely(self):
        self.config.write({
            "firebase_service_account_file": base64.b64encode(b"this is not json"),
        })
        # No exception raised; status flips to invalid, metadata cleared.
        self.assertEqual(self.config.firebase_validation_status, "invalid")
        self.assertTrue(self.config.firebase_validation_message)
        self.assertFalse(self.config.firebase_project_id)

    def test_validate_structurally_valid_credentials(self):
        self.config.write({"firebase_service_account_file": self.valid_b64})
        self.config.action_validate_firebase_credentials()
        # In test mode the live Google check is skipped -> structural 'valid'.
        self.assertEqual(self.config.firebase_validation_status, "valid")
        self.assertTrue(self.config.firebase_last_validation_date)

    def test_validate_missing_required_key_is_invalid(self):
        incomplete = make_service_account(drop=["private_key"])
        self.config.write({
            "firebase_service_account_file": encode_service_account(incomplete),
        })
        self.config.action_validate_firebase_credentials()
        self.assertEqual(self.config.firebase_validation_status, "invalid")

    def test_enabling_push_without_credentials_is_rejected(self):
        # Clear any file first: a dev database may already hold a real service account.
        self.config.write({
            "push_notifications_enabled": False,
            "firebase_service_account_file": False,
        })
        with self.assertRaises(ValidationError):
            self.config.write({"push_notifications_enabled": True})

    def test_enabling_push_with_credentials_succeeds(self):
        self.config.with_user(self.admin).write({
            "firebase_service_account_file": self.valid_b64,
        })
        self.config.write({"push_notifications_enabled": False})
        self.config.write({"push_notifications_enabled": True})  # no raise
        self.assertTrue(self.config.push_notifications_enabled)

    def test_clear_credentials_allows_reupload(self):
        self.config.with_user(self.admin).write({
            "push_notifications_enabled": False,
            "firebase_service_account_file": self.valid_b64,
            "firebase_service_account_filename": "old-sa.json",
        })
        self.config.with_user(self.admin).write({"push_notifications_enabled": True})

        self.config.with_user(self.admin).action_clear_firebase_credentials()

        self.assertFalse(self.config.push_notifications_enabled)
        self.assertFalse(self.config.firebase_service_account_file)
        self.assertFalse(self.config.firebase_service_account_filename)
        self.assertFalse(self.config.firebase_project_id)
        self.assertEqual(self.config.firebase_validation_status, "not_validated")

        replacement = make_service_account(
            overrides={"project_id": "replacement-project"})
        self.config.with_user(self.admin).write({
            "firebase_service_account_file": encode_service_account(replacement),
            "firebase_service_account_filename": "new-sa.json",
        })
        self.assertEqual(self.config.firebase_project_id, "replacement-project")

    def test_admin_can_configure_but_manager_cannot(self):
        self.config.with_user(self.admin).write({
            "firebase_service_account_file": self.valid_b64,
        })
        self.assertEqual(self.config.firebase_project_id, "test-project")

        # Manager cannot touch Firebase config (field groups) though push_notifications_enabled stays editable.
        with self.assertRaises(AccessError):
            self.config.with_user(self.manager).write({
                "firebase_service_account_file": self.valid_b64,
            })

    def test_private_key_not_exposed_to_manager(self):
        self.config.write({"firebase_service_account_file": self.valid_b64})
        # The Binary holding the private key is unreadable to a non-admin.
        with self.assertRaises(AccessError):
            self.config.with_user(self.manager).read(
                ["firebase_service_account_file"])
