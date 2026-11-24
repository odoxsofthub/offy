from odoo.tests import TransactionCase, tagged


@tagged("-at_install", "post_install")
class TestMobileUserSessionPushVisibility(TransactionCase):
    """`show_push_tokens` must mirror `mobile.config.push_notifications_enabled`."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        cls.user = cls.env["res.users"].create({
            "name": "Session Visibility User",
            "login": "session_visibility_user@test.com",
            "group_ids": [(4, mobile_group.id)],
        })
        cls.session = cls.env["mobile.user.session"].create({
            "user_id": cls.user.id,
        })
        cls.config = cls.env["mobile.config"].get_config()

    def _enable_push_notifications(self):
        """Flip the flag on, satisfying this module's own Firebase
        credential-presence constraint (see mobile_config.py)."""
        self.config.sudo().write({
            "firebase_service_account_file": b"e30=",  # base64 of "{}"
        })
        self.config.push_notifications_enabled = True

    def test_show_push_tokens_true_when_enabled(self):
        self._enable_push_notifications()
        self.assertTrue(self.session.show_push_tokens)

    def test_show_push_tokens_false_when_disabled(self):
        self.config.push_notifications_enabled = False
        self.assertFalse(self.session.show_push_tokens)
