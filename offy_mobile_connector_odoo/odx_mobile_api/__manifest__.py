{
    "name": "OFFY Connector API",
    "version": "19.0.1.90.0",
    # Tokens are core `res.users.apikeys` rows; the hook purges them on uninstall.
    "uninstall_hook": "uninstall_hook",
    "license": "LGPL-3",
    "category": "Tools",
    "summary": "REST authentication & API layer for the OFFY Connector",
    "description": """
OFFY Connector API
==================
HTTP/REST endpoints for the Flutter mobile application, built on top of
``odx_mobile_connector``.

Provides authentication plus attendance, time off, payslip, profile and
expense endpoints for the mobile app. See README.md for installation and
authentication details.

Access tokens are Odoo API keys (``res.users.apikeys``, scope ``mobile_api``).
Refresh tokens are stored hashed (``mobile.refresh.token``) and rotated on use.
Eligibility is enforced through the connector (Mobile User group + mobile.config).

.. important::
   This module is **Odoo Enterprise only**. It depends on ``hr_payroll``
   (OEEL), so the server's ``addons_path`` MUST include the enterprise
   addons directory. On a Community install (no enterprise path), the
   connector's pre-install check stops the installation with a clear message
   explaining that ``hr_payroll`` and the Enterprise addons path are required.
   On Enterprise deployments, installing ``odx_mobile_connector``
   automatically installs this API module too.
""",
    "author": "Odox SoftHub LLP",
    "website": "https://odoxsofthub.com/",
    "maintainers": ["Odox SoftHub LLP"],
    "depends": [
        # bus: controllers/realtime.py reads the websocket worker version from it.
        "odx_mobile_connector", "bus", "web", "resource",
        "hr_attendance", "hr_holidays",
        # hr_payroll is Enterprise-only (OEEL).
        "hr_payroll",
        "hr_expense",
        "calendar",
    ],
    "data": [
        "security/ir.model.access.csv",
        "data/refresh_token_cron.xml",
        "views/product_template_views.xml",
    ],
    # Installs automatically together with odx_mobile_connector.
    "auto_install": ["odx_mobile_connector"],
    "application": False,
    "installable": True,
}
