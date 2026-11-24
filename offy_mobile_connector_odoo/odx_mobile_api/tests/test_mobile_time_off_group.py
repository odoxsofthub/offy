"""Odoo 20: Mobile Users get hr_holidays.group_hr_holidays_employee (tracker R8 / #7, option a).

Odoo 20 gives time off read access only to that group. A mobile user gets it when they become a
Mobile User (connector flag, direct group change or create), on the 20.0.1.90.0 upgrade and on a
fresh install, but never again on unrelated writes after an admin removed it.
"""
import importlib.util
from pathlib import Path

from odoo.fields import Command
from odoo.tests import TransactionCase, tagged

from .. import post_init_hook

MIGRATION = Path(__file__).resolve().parent.parent / "migrations" / "20.0.1.90.0" / "post-migrate.py"


def _load_migration():
    spec = importlib.util.spec_from_file_location("odx_mobile_api_post_migrate_20", MIGRATION)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@tagged("post_install", "-at_install")
class TestMobileTimeOffGroup(TransactionCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.time_off_group = cls.env.ref("hr_holidays.group_hr_holidays_employee")
        cls.mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        cls.internal_group = cls.env.ref("base.group_user")
        cls.Users = cls.env["res.users"].with_context(no_reset_password=True)

    def _user(self, login, mobile=False, active=True):
        groups = [self.internal_group.id] + ([self.mobile_group.id] if mobile else [])
        return self.Users.create({
            "name": login, "login": login, "active": active,
            "group_ids": [Command.set(groups)],
        })

    def _strip_time_off_group(self, users):
        """Simulate an upgraded v19 user, written below the ORM hooks."""
        self.env.cr.execute(
            "DELETE FROM res_groups_users_rel WHERE gid = %s AND uid = ANY(%s)",
            [self.time_off_group.id, users.ids])
        users.invalidate_recordset(["group_ids", "all_group_ids"])

    def _has(self, user):
        user.invalidate_recordset(["group_ids", "all_group_ids"])
        return self.time_off_group in user.all_group_ids

    def test_internal_user_with_explicit_groups_lacks_it(self):
        # The premise: explicit group_ids skip the default template, so v20 gives no time off access.
        self.assertFalse(self._has(self._user("odx.tog.plain")))

    def test_create_as_mobile_user_adds_it(self):
        self.assertTrue(self._has(self._user("odx.tog.create", mobile=True)))

    def test_connector_flag_adds_it(self):
        user = self._user("odx.tog.flag")
        user.mobile_user = True
        self.assertTrue(user.mobile_user)
        self.assertTrue(self._has(user))

    def test_direct_group_change_adds_it(self):
        user = self._user("odx.tog.direct")
        user.write({"group_ids": [Command.link(self.mobile_group.id)]})
        self.assertTrue(self._has(user))

    def test_removed_group_is_not_re_added_on_unrelated_writes(self):
        user = self._user("odx.tog.removed", mobile=True)
        user.write({"group_ids": [Command.unlink(self.time_off_group.id)]})
        self.assertFalse(self._has(user), "the admin's removal must stick")
        user.write({"name": "Renamed"})
        user.write({"group_ids": [Command.link(self.env.ref("base.group_allow_export").id)]})
        user.mobile_user = True  # already a mobile user: no transition
        self.assertTrue(user.mobile_user)
        self.assertFalse(self._has(user))

    def test_becoming_mobile_again_adds_it(self):
        user = self._user("odx.tog.again", mobile=True)
        user.write({"group_ids": [Command.unlink(self.time_off_group.id)]})
        user.mobile_user = False
        user.mobile_user = True
        self.assertTrue(self._has(user))

    def test_migration_adds_it_to_active_mobile_users_only(self):
        mobile = self._user("odx.tog.mig.mobile", mobile=True)
        other = self._user("odx.tog.mig.other")
        archived = self._user("odx.tog.mig.archived", mobile=True, active=False)
        self._strip_time_off_group(mobile | archived)
        self.assertFalse(self._has(mobile))

        _load_migration().migrate(self.env.cr, "19.0.1.90.0")

        self.assertTrue(self._has(mobile))
        self.assertFalse(self._has(other), "non-mobile users are left alone")
        self.assertFalse(self._has(archived), "archived users are left alone")

    def test_migration_skips_fresh_install(self):
        mobile = self._user("odx.tog.mig.fresh", mobile=True)
        self._strip_time_off_group(mobile)
        _load_migration().migrate(self.env.cr, None)
        self.assertFalse(self._has(mobile))

    def test_post_init_hook_adds_it(self):
        mobile = self._user("odx.tog.hook", mobile=True)
        self._strip_time_off_group(mobile)
        post_init_hook(self.env)
        self.assertTrue(self._has(mobile))
