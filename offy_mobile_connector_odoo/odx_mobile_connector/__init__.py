from . import models

from odoo.exceptions import UserError
from odoo.modules.module import get_manifest


def pre_init_hook(env):
    """Fail early with an actionable message when the auto-installed API cannot load (e.g. Payroll missing).
    Runs before the connector schema is created, instead of Odoo's generic dependency failure.
    """
    api_manifest = get_manifest("odx_mobile_api")
    if not api_manifest:
        raise UserError(
            "OFFY Connector API is missing. Copy both 'odx_mobile_connector' "
            "and 'odx_mobile_api' to an addons_path, update the Apps List, "
            "then try again."
        )

    required = set(api_manifest.get("depends", ())) - {"odx_mobile_connector"}
    available = env["ir.module.module"].sudo().search([
        ("name", "in", list(required)),
    ])
    available_by_name = {module.name: module for module in available}
    missing = sorted(required - set(available_by_name))
    unavailable = sorted(
        name for name, module in available_by_name.items()
        if module.state == "uninstallable"
    )
    if not missing and not unavailable:
        return

    unavailable_names = missing + unavailable
    enterprise_hint = ""
    if "hr_payroll" in unavailable_names:
        enterprise_hint = (
            " The bundled Payslip API requires Odoo 19 Enterprise; add the "
            "Enterprise addons directory to addons_path."
        )
    raise UserError(
        "OFFY Connector cannot be installed because required module(s) are "
        "unavailable: %s. Make those modules available, update the Apps List, "
        "and try again.%s" % (", ".join(unavailable_names), enterprise_hint)
    )
