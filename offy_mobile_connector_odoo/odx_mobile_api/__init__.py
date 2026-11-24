import logging

from . import models
from . import controllers

_logger = logging.getLogger(__name__)

# Keep in sync with controllers/main.py.
API_KEY_SCOPE = "mobile_api"


def uninstall_hook(env):
    """Purge the mobile API keys this module minted; they live in core `res.users.apikeys`.
    Uninstall would otherwise leave them as orphaned credentials. Scoped to `mobile_api` only."""
    keys = env["res.users.apikeys"].sudo().search([("scope", "=", API_KEY_SCOPE)])
    count = len(keys)
    if not count:
        return
    # `res.users.apikeys` has no unlink ACL, so delete by SQL (no sudo).
    env.cr.execute(
        "DELETE FROM %s WHERE scope = %%s" % env["res.users.apikeys"]._table,
        (API_KEY_SCOPE,),
    )
    _logger.info("odx_mobile_api uninstall: removed %s mobile access token(s).", count)
