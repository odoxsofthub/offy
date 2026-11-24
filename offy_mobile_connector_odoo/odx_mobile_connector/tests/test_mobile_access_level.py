from odoo.tests.common import TransactionCase, tagged


@tagged("post_install", "-at_install")
class TestMobileAccessLevel(TransactionCase):
    """Access Level must reflect, and never silently strip, the connector groups."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.Users = cls.env["res.users"].with_context(no_reset_password=True)
        cls.internal = cls.env.ref("base.group_user")
        cls.viewer = cls.env.ref("odx_mobile_connector.group_mobile_viewer")
        cls.manager = cls.env.ref("odx_mobile_connector.group_mobile_manager")
        cls.admin = cls.env.ref("odx_mobile_connector.group_mobile_admin")

    def _create(self, login, groups=(), **vals):
        return self.Users.create({
            "name": login,
            "login": login,
            "groups_id": [(4, self.internal.id)] + [(4, g.id) for g in groups],
            **vals,
        })

    def test_groups_given_at_create_are_kept(self):
        for group, level in ((self.viewer, "viewer"), (self.manager, "manager"), (self.admin, "admin")):
            with self.subTest(level=level):
                user = self._create("lvl_%s@test.com" % level, [group])
                self.assertIn(group, user.groups_id)
                self.assertEqual(user.mobile_access_level, level)

    def test_create_without_groups_is_no_access(self):
        user = self._create("lvl_none@test.com")
        self.assertEqual(user.mobile_access_level, "none")

    def test_access_level_given_at_create_is_applied(self):
        user = self._create("lvl_field@test.com", mobile_access_level="manager")
        self.assertIn(self.manager, user.groups_id)

    def test_copy_keeps_the_access_level(self):
        user = self._create("lvl_src@test.com", [self.manager])
        copy = user.copy({"login": "lvl_copy@test.com"})
        self.assertIn(self.manager, copy.groups_id)
        self.assertEqual(copy.mobile_access_level, "manager")

    def test_changing_the_level_switches_groups(self):
        user = self._create("lvl_change@test.com", [self.viewer])
        user.mobile_access_level = "admin"
        self.assertIn(self.admin, user.groups_id)
        self.assertEqual(user.mobile_access_level, "admin")
        # Odoo 18 keeps implied groups in groups_id, so an admin also holds viewer; check the downgrade instead.
        user.mobile_access_level = "viewer"
        self.assertIn(self.viewer, user.groups_id)
        self.assertFalse(user.groups_id & (self.manager | self.admin))
        user.mobile_access_level = "none"
        self.assertFalse(user.groups_id & (self.viewer | self.manager | self.admin))
