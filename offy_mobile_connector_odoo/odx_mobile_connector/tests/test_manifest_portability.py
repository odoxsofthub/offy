from odoo.modules.module import get_manifest
from odoo.tests.common import TransactionCase, tagged


@tagged("post_install", "-at_install")
class TestConnectorManifestPortability(TransactionCase):
    """Guards the connector's packaging contract (Community-only dependencies)."""

    # Everything the connector may depend on; all Community modules.
    ALLOWED_DEPENDS = {"bus", "mail", "hr", "hr_attendance"}

    def setUp(self):
        super().setUp()
        self.manifest = get_manifest("odx_mobile_connector")
        self.assertTrue(self.manifest, "connector manifest must be discoverable")

    def test_no_enterprise_dependencies(self):
        depends = set(self.manifest.get("depends", []))
        unexpected = depends - self.ALLOWED_DEPENDS
        self.assertFalse(
            unexpected,
            "odx_mobile_connector gained unexpected dependencies %s; the "
            "foundation layer must stay Community-installable." % sorted(unexpected),
        )

    def test_not_auto_install(self):
        # False, [] or a falsy set are all acceptable; a truthy value is not.
        self.assertFalse(
            self.manifest.get("auto_install"),
            "the connector must not auto-install",
        )

    def test_has_dependency_preflight_hook(self):
        self.assertEqual(
            self.manifest.get("pre_init_hook"), "pre_init_hook",
            "connector installation must report missing API dependencies clearly",
        )

    def test_installable(self):
        self.assertTrue(self.manifest.get("installable"))
