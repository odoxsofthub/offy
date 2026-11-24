-- Neutralization for odx_mobile_api.
--
-- Picked up automatically by `odoo-bin neutralize` for every installed module
-- (odoo/modules/neutralize.py -> get_neutralization_queries reads
-- "<module>/data/neutralize.sql"). Deliberately NOT in the manifest's "data"
-- key: it must never run at install or upgrade, only when an administrator
-- explicitly neutralizes a copy of the database.
--
-- Purpose: strip the mobile authentication material, so a copy of this
-- database cannot be used to act as an already-signed-in employee.

-- Refresh tokens (hashed, rotated on use). Deleting the parent rows also
-- clears mobile_refresh_token_company_rel, whose FK is ON DELETE CASCADE.
DELETE FROM mobile_refresh_token;

-- Access tokens.
-- These are core `res.users.apikeys` rows, not a table of ours, so they would
-- survive untouched otherwise -- the same reason uninstall_hook() in
-- __init__.py exists. Scoped to 'mobile_api' so API keys the customer created
-- for anything else are never touched. Keep the scope string in sync with
-- API_KEY_SCOPE in __init__.py and controllers/main.py.
DELETE FROM res_users_apikeys WHERE scope = 'mobile_api';
