from datetime import timedelta

from odoo import fields
from odoo.modules.neutralize import get_neutralization_queries
from odoo.tests import TransactionCase, tagged

from .. import API_KEY_SCOPE

MODULE = "odx_mobile_api"


@tagged("post_install", "-at_install")
class TestNeutralize(TransactionCase):
    """`data/neutralize.sql` must strip mobile refresh tokens and API keys.
    Otherwise a database copy lets its holder act as signed-in employees."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.queries = list(get_neutralization_queries([MODULE]))
        cls.user = cls.env.ref("base.user_admin")

    def test_neutralize_sql_is_discovered(self):
        self.assertEqual(
            len(self.queries), 1,
            "expected exactly one neutralize.sql for %s" % MODULE)
        self.assertTrue(self.queries[0].strip(), "neutralize.sql is empty")

    def test_neutralize_sql_is_not_a_manifest_data_file(self):
        """It must never run at install or upgrade -- only on demand."""
        manifest = self.env["ir.module.module"].get_module_info(MODULE)
        self.assertNotIn("data/neutralize.sql", manifest.get("data", []))

    def test_scope_constant_matches_the_sql(self):
        """The SQL hard-codes the scope; keep it equal to API_KEY_SCOPE."""
        self.assertIn("'%s'" % API_KEY_SCOPE, self.queries[0])

    def _run_neutralize(self):
        for query in self.queries:
            self.env.cr.execute(query)
        self.env.invalidate_all()

    def test_purges_refresh_tokens(self):
        self.env["mobile.refresh.token"].sudo().create({
            "user_id": self.user.id,
            "token_index": "idx",
            "token_hash": "hash",
            "expires_at": fields.Datetime.now() + timedelta(days=30),
        })
        self.env.flush_all()

        self._run_neutralize()

        self.assertFalse(
            self.env["mobile.refresh.token"].sudo().search_count([]),
            "refresh tokens survived neutralization")

    def test_purges_mobile_access_tokens_only(self):
        """Mobile API keys go; API keys created for anything else stay."""
        keys = self.env["res.users.apikeys"].with_user(self.user).sudo()
        keys._generate(API_KEY_SCOPE, "mobile token", False)
        keys._generate("some_other_integration", "unrelated token", False)
        self.env.flush_all()

        self._run_neutralize()

        self.env.cr.execute(
            "SELECT scope, count(*) FROM res_users_apikeys GROUP BY scope")
        remaining = dict(self.env.cr.fetchall())
        self.assertNotIn(
            API_KEY_SCOPE, remaining,
            "mobile access tokens survived neutralization")
        self.assertEqual(
            remaining.get("some_other_integration"), 1,
            "neutralization deleted an unrelated integration's API key")
