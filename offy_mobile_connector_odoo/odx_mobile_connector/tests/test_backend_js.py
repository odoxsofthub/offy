from odoo.tests import HttpCase, tagged

# Polls for a rendered form or list; any console error (e.g. an OWL template failure) fails the test.
WAIT_FOR_VIEW = """
const started = Date.now();
const check = () => {
    if (document.querySelector('.o_form_view, .o_list_view')) {
        console.log('test successful');
    } else if (Date.now() - started > 20000) {
        console.error('the view never rendered');
    } else {
        setTimeout(check, 200);
    }
};
check();
"""


@tagged("post_install", "-at_install")
class TestBackendJs(HttpCase):
    """The backend and the connector's screens load in a real browser without JS errors."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        # browser_js logs in with password == login.
        cls.env["res.users"].create({
            "name": "OFFY JS Admin",
            "login": "offy_js_admin",
            "password": "offy_js_admin",
            "email": "offy_js_admin@test.com",
            "groups_id": [
                (4, cls.env.ref("base.group_system").id),
                (4, cls.env.ref("odx_mobile_connector.group_mobile_admin").id),
            ],
        })

    def test_backend_loads(self):
        self.browser_js("/odoo", "console.log('test successful')", "odoo.isReady",
                        login="offy_js_admin")

    def test_feature_form_with_access_widget_and_chatter(self):
        feature = self.env.ref("odx_mobile_connector.feature_leave")
        self.browser_js(
            "/odoo/action-odx_mobile_connector.action_mobile_feature/%s" % feature.id,
            WAIT_FOR_VIEW, "odoo.isReady", login="offy_js_admin")

    def test_config_screen(self):
        self.browser_js(
            "/odoo/action-odx_mobile_connector.action_mobile_config",
            WAIT_FOR_VIEW, "odoo.isReady", login="offy_js_admin")
