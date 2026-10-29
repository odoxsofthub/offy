from odoo.exceptions import ValidationError
from odoo.tests.common import TransactionCase, tagged


@tagged("post_install", "-at_install")
class TestResUsersMobileInternalOnly(TransactionCase):
    """Mobile groups must never be held by portal or public users, by any grant path.
    Keyed on group_portal/group_public, not `share`: mobile-only employees are share=True but allowed."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.Users = cls.env["res.users"].with_context(no_reset_password=True)
        cls.portal_group = cls.env.ref("base.group_portal")
        cls.internal_group = cls.env.ref("base.group_user")
        cls.mobile_user_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        cls.viewer_group = cls.env.ref("odx_mobile_connector.group_mobile_viewer")
        cls.manager_group = cls.env.ref("odx_mobile_connector.group_mobile_manager")
        cls.admin_group = cls.env.ref("odx_mobile_connector.group_mobile_admin")

    def _portal_user(self, login):
        return self.Users.create({
            "name": login,
            "login": login,
            "group_ids": [(6, 0, [self.portal_group.id])],
        })

    def _internal_user(self, login):
        return self.Users.create({
            "name": login,
            "login": login,
            "group_ids": [(6, 0, [self.internal_group.id])],
        })

    def _public_user(self, login):
        return self.Users.create({
            "name": login,
            "login": login,
            "group_ids": [(6, 0, [self.env.ref("base.group_public").id])],
        })

    def test_group_ids_direct_grant_is_blocked(self):
        user = self._portal_user("portal_group_ids@test.com")
        with self.assertRaises(ValidationError):
            user.write({"group_ids": [(4, self.mobile_user_group.id)]})

    def test_mobile_user_boolean_inverse_is_blocked(self):
        user = self._portal_user("portal_mobile_user@test.com")
        with self.assertRaises(ValidationError):
            user.write({"mobile_user": True})

    def test_mobile_access_level_viewer_is_blocked(self):
        user = self._portal_user("portal_viewer@test.com")
        with self.assertRaises(ValidationError):
            user.write({"mobile_access_level": "viewer"})

    def test_mobile_access_level_manager_is_blocked(self):
        user = self._portal_user("portal_manager@test.com")
        with self.assertRaises(ValidationError):
            user.write({"mobile_access_level": "manager"})

    def test_mobile_access_level_admin_is_blocked(self):
        user = self._portal_user("portal_admin@test.com")
        with self.assertRaises(ValidationError):
            user.write({"mobile_access_level": "admin"})

    def test_public_user_group_ids_grant_is_blocked(self):
        user = self._public_user("public_group_ids@test.com")
        with self.assertRaises(ValidationError):
            user.write({"group_ids": [(4, self.mobile_user_group.id)]})

    def test_create_time_grant_is_blocked(self):
        """The import/API path: the mobile group is already in `group_ids`
        at `create()`, never added by a later `write()`."""
        with self.assertRaises(ValidationError):
            self.Users.create({
                "name": "Portal Create Grant",
                "login": "portal_create_grant@test.com",
                "group_ids": [(6, 0, [self.portal_group.id, self.mobile_user_group.id])],
            })

    def test_becoming_portal_while_holding_mobile_group_is_blocked(self):
        """Demoting a mobile user to portal is blocked.
        Uses explicit link/unlink; a (6, 0, ...) replace would also strip the mobile group."""
        user = self._internal_user("was_internal@test.com")
        user.write({"mobile_user": True})
        self.assertTrue(user.mobile_user)
        with self.assertRaises(ValidationError):
            user.write({"group_ids": [
                (3, self.internal_group.id),
                (4, self.portal_group.id),
            ]})

    def test_internal_user_can_still_get_mobile_user(self):
        user = self._internal_user("internal_mobile_user@test.com")
        user.write({"mobile_user": True})
        self.assertTrue(user.mobile_user)
        self.assertIn(self.mobile_user_group, user.group_ids)

    def test_internal_user_can_still_get_admin_access_level(self):
        user = self._internal_user("internal_admin@test.com")
        user.write({"mobile_access_level": "admin"})
        self.assertEqual(user.mobile_access_level, "admin")
        self.assertIn(self.admin_group, user.group_ids)

    def test_internal_user_can_still_get_all_four_groups_via_group_ids(self):
        user = self._internal_user("internal_all_groups@test.com")
        user.write({"group_ids": [
            (4, self.mobile_user_group.id),
            (4, self.viewer_group.id),
            (4, self.manager_group.id),
            (4, self.admin_group.id),
        ]})
        held = user.group_ids
        for group in (self.mobile_user_group, self.viewer_group,
                      self.manager_group, self.admin_group):
            self.assertIn(group, held)

    # Mobile-only employees (no base.group_user seat) are not portal/public and must stay allowed.
    def test_mobile_only_employee_with_no_internal_group_is_allowed(self):
        """A user with only group_mobile_user (share=True but not portal/public) is allowed."""
        user = self.Users.create({
            "name": "Mobile Only Employee",
            "login": "mobile_only_employee@test.com",
            "group_ids": [(6, 0, [self.mobile_user_group.id])],
        })
        self.assertTrue(user.share, "sanity: this user IS share=True")
        self.assertFalse(user.is_mobile_restricted_user)
        self.assertTrue(user.mobile_user)
        self.assertIn(self.mobile_user_group, user.group_ids)

    def test_mobile_only_employee_can_also_get_an_access_level(self):
        user = self.Users.create({
            "name": "Mobile Only Manager",
            "login": "mobile_only_manager@test.com",
            "group_ids": [(6, 0, [self.mobile_user_group.id])],
        })
        user.write({"mobile_access_level": "manager"})
        self.assertEqual(user.mobile_access_level, "manager")
        self.assertIn(self.manager_group, user.group_ids)
