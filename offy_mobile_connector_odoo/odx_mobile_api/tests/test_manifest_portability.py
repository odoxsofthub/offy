from odoo.modules.module import get_manifest
from odoo.tests.common import TransactionCase, tagged


@tagged("post_install", "-at_install")
class TestApiManifestPortability(TransactionCase):
    """Portability contract: auto_install only via odx_mobile_connector; hr_payroll stays declared
    so Community fails at install time with a clear missing-dependency error."""

    def setUp(self):
        super().setUp()
        self.manifest = get_manifest("odx_mobile_api")
        self.assertTrue(self.manifest, "api manifest must be discoverable")

    def test_auto_installs_with_connector_only(self):
        self.assertEqual(
            set(self.manifest.get("auto_install") or []),
            {"odx_mobile_connector"},
            "odx_mobile_api must auto-install when the main Mobile "
            "Connector is installed on a supported server.",
        )

    def test_enterprise_dependency_is_declared(self):
        depends = set(self.manifest.get("depends", []))
        self.assertIn(
            "hr_payroll", depends,
            "hr_payroll must stay declared so Community installs fail with a "
            "clear dependency message rather than a registry traceback.",
        )
        self.assertIn(
            "odx_mobile_connector", depends,
            "the API must depend on its foundation connector module.",
        )

    def test_version_matches_connector(self):
        connector = get_manifest("odx_mobile_connector")
        self.assertEqual(
            self.manifest.get("version"), connector.get("version"),
            "api and connector versions should stay in lock-step.",
        )
