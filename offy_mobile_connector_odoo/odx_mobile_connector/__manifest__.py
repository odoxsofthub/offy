{
    "name": "OFFY Connector",
    "version": "19.0.1.90.0",
    "pre_init_hook": "pre_init_hook",
    "license": "LGPL-3",
    "category": "Tools",
    "summary": "Foundation/configuration layer for a Flutter mobile application",
    "description": """
OFFY Connector
==============
Provides the configuration and management backbone required to build a
Flutter based mobile application on top of Odoo.

This module only delivers the data architecture (models, security, views and
default data). It intentionally does NOT implement controllers, REST APIs,
authentication flows or business features so that those can be layered on top
by future modules without touching this core.
""",
    "author": "Odox SoftHub LLP",
    "website": "https://odoxsofthub.com/",
    "maintainers": ["Odox SoftHub LLP"],
    # bus: the websocket / bus.bus channel realtime sync rides on.
    "depends": ["bus", "mail", "hr", "hr_attendance"],
    "data": [
        # Security must load first so groups/access rights are available.
        "security/mobile_security.xml",
        "security/ir.model.access.csv",
        "data/mobile_feature_data.xml",
        "data/mobile_config_data.xml",
        "data/mobile_push_cron.xml",
        "data/mobile_content_data.xml",
        "views/mobile_feature_views.xml",
        "views/mobile_config_views.xml",
        "views/mobile_session_views.xml",
        # Extends view_mobile_config_form, so it must load after mobile_config_views.xml.
        "views/mobile_config_firebase_views.xml",
        # Content views must load before mobile_content_menus.xml, which references their actions.
        "views/mobile_content_views.xml",
        "views/mobile_menus.xml",
        "views/mobile_content_menus.xml",
        "views/res_users_views.xml",
        "views/hr_attendance_views.xml",
        "views/hr_work_location_views.xml",
    ],
    "assets": {
        "web.assets_backend": [
            "odx_mobile_connector/static/src/js/user_access_search.js",
            "odx_mobile_connector/static/src/xml/chatter_inherit.xml",
        ],
    },
    "application": True,
    "installable": True,
    "auto_install": False,
}
