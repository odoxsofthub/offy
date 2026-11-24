from odoo.exceptions import AccessError, ValidationError
from odoo.tests.common import TransactionCase, tagged


@tagged("post_install", "-at_install")
class TestMobileContent(TransactionCase):
    """Privacy Policy / Terms & Conditions singletons, FAQ list and their ACLs."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.Privacy = cls.env["mobile.privacy.policy"]
        cls.Terms = cls.env["mobile.terms.condition"]
        cls.Faq = cls.env["mobile.faq"]

        Users = cls.env["res.users"].with_context(no_reset_password=True)
        internal = cls.env.ref("base.group_user")
        cls.viewer = Users.create({
            "name": "Content Viewer",
            "login": "content_viewer@test.com",
            "group_ids": [(4, internal.id), (
                4, cls.env.ref("odx_mobile_connector.group_mobile_viewer").id)],
        })
        cls.manager = Users.create({
            "name": "Content Manager",
            "login": "content_manager@test.com",
            "group_ids": [(4, internal.id), (
                4, cls.env.ref("odx_mobile_connector.group_mobile_manager").id)],
        })
        cls.admin = Users.create({
            "name": "Content Admin",
            "login": "content_admin@test.com",
            "group_ids": [(4, internal.id), (
                4, cls.env.ref("odx_mobile_connector.group_mobile_admin").id)],
        })
        # A plain mobile app user (the API caller) — read-only on content.
        cls.mobile_user = Users.create({
            "name": "Content Mobile User",
            "login": "content_mobile_user@test.com",
            "group_ids": [(4, internal.id), (
                4, cls.env.ref("odx_mobile_connector.group_mobile_user").id)],
        })

    def test_default_records_exist_and_unpublished(self):
        privacy = self.env.ref(
            "odx_mobile_connector.mobile_privacy_policy_default")
        terms = self.env.ref(
            "odx_mobile_connector.mobile_terms_condition_default")
        self.assertTrue(privacy)
        self.assertTrue(terms)
        self.assertFalse(privacy.is_published)
        self.assertFalse(terms.is_published)
        # No FAQ demo/seed rows are shipped.
        self.assertEqual(self.Faq.search_count([]), 0)

    def test_privacy_html_round_trip(self):
        policy = self.Privacy.get_privacy_policy()
        policy.write({
            "body": "<p>Our <strong>privacy</strong> policy.</p>",
            "is_published": True,
        })
        self.assertIn("<strong>privacy</strong>", policy.body)
        self.assertTrue(policy.is_published)

    def test_terms_html_round_trip(self):
        terms = self.Terms.get_terms()
        terms.write({"body": "<p>These are the <em>terms</em>.</p>"})
        self.assertIn("<em>terms</em>", terms.body)

    def test_privacy_is_singleton(self):
        # A default record already exists (from data), so a second create fails.
        self.assertTrue(self.Privacy.search_count([]) >= 1)
        with self.assertRaises(ValidationError):
            self.Privacy.create({"name": "Second policy"})

    def test_terms_is_singleton(self):
        self.assertTrue(self.Terms.search_count([]) >= 1)
        with self.assertRaises(ValidationError):
            self.Terms.create({"name": "Second terms"})

    def test_privacy_cannot_be_deleted(self):
        with self.assertRaises(ValidationError):
            self.Privacy.get_privacy_policy().unlink()

    def test_terms_cannot_be_deleted(self):
        with self.assertRaises(ValidationError):
            self.Terms.get_terms().unlink()

    def test_get_helpers_return_single_record(self):
        self.assertEqual(len(self.Privacy.get_privacy_policy()), 1)
        self.assertEqual(len(self.Terms.get_terms()), 1)

    def test_faq_create_and_ordering(self):
        second = self.Faq.create({
            "heading": "Second", "sub_heading": "b", "sequence": 20})
        first = self.Faq.create({
            "heading": "First", "sub_heading": "a", "sequence": 10})
        ordered = self.Faq.search([])
        self.assertEqual(ordered[0], first)
        self.assertEqual(ordered[1], second)
        self.assertEqual(first.sub_heading, "a")
        self.assertTrue(first.active)

    def test_faq_active_default(self):
        faq = self.Faq.create({"heading": "Q", "sub_heading": "a"})
        self.assertTrue(faq.active)

    def test_faq_sub_heading_required(self):
        self.assertTrue(self.Faq._fields["sub_heading"].required)

    def test_viewer_cannot_write_privacy(self):
        policy = self.Privacy.get_privacy_policy()
        with self.assertRaises(AccessError):
            policy.with_user(self.viewer).write({"body": "<p>x</p>"})

    def test_manager_can_write_privacy(self):
        policy = self.Privacy.get_privacy_policy()
        policy.with_user(self.manager).write({"body": "<p>ok</p>"})
        self.assertIn("ok", policy.body)

    def test_viewer_cannot_create_faq(self):
        with self.assertRaises(AccessError):
            self.Faq.with_user(self.viewer).create(
                {"heading": "Nope", "sub_heading": "x"})

    def test_manager_can_create_faq_but_not_unlink(self):
        faq = self.Faq.with_user(self.manager).create(
            {"heading": "M", "sub_heading": "x"})
        self.assertTrue(faq)
        with self.assertRaises(AccessError):
            faq.with_user(self.manager).unlink()

    def test_admin_can_unlink_faq(self):
        faq = self.Faq.create({"heading": "Del", "sub_heading": "x"})
        faq.with_user(self.admin).unlink()
        self.assertFalse(faq.exists())

    def test_mobile_user_reads_content_without_sudo(self):
        """The API caller (group_mobile_user) reads Other Data under its OWN
        rights (read ACL, no sudo) but cannot modify it."""
        policy = self.Privacy.get_privacy_policy()
        policy.with_user(self.mobile_user).read(["name", "body", "is_published"])
        self.Terms.get_terms().with_user(self.mobile_user).read(["name", "body"])
        faq = self.Faq.create({"heading": "Q", "sub_heading": "a"})
        faq.with_user(self.mobile_user).read(["heading", "sub_heading"])
        # ...but writes/creates are denied (read-only ACL).
        with self.assertRaises(AccessError):
            policy.with_user(self.mobile_user).write({"body": "<p>no</p>"})
        with self.assertRaises(AccessError):
            self.Faq.with_user(self.mobile_user).create(
                {"heading": "X", "sub_heading": "y"})
