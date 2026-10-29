# OFFY Connector API

REST authentication layer for the Flutter mobile app, built on
`odx_mobile_connector`.

## ⚠️ Requires Odoo Enterprise

This module depends on **`hr_payroll`** (Odoo Enterprise / OEEL) for the
payslip feature, so the server's `addons_path` **must include the enterprise
addons directory**. On a Community install Odoo will refuse to install this
module with a clear declared-dependency error
(`... depends on hr_payroll which was not found`) — this is expected, not a bug.

This bundled two-module package is for Odoo 19 Enterprise. On a server without
Enterprise Payroll, **neither module installs** -- not even OFFY Connector on
its own, because installing it automatically pulls in this API module. The
message shown is Odoo's own dependency error:

    You try to install module "odx_mobile_api" that depends on module "hr_payroll".

Fix: add the Odoo 19 Enterprise addons directory to `addons_path`, restart,
update the Apps List, and install again.

Install is automatic on a supported Enterprise server: installing
**OFFY Connector** also installs this API module and its declared Odoo
dependencies.

### Target-system requirements
- Odoo 19 **Enterprise**, with the enterprise addons dir on `addons_path`.
- `custom/` on `addons_path` (so both custom modules are discoverable).
- Python: no extra packages beyond Odoo core — `cryptography`/`requests`/`pytz`
  ship with Odoo (the connector imports the optional FCM ones lazily).

## Installation

1. Copy both `odx_mobile_connector` and `odx_mobile_api` into a directory on
   the target Odoo server's `addons_path`.
2. Ensure the target is Odoo 19 Enterprise and its Enterprise addons directory
   is also on `addons_path`.
3. In Apps, update the Apps List and install **OFFY Connector**. The API
   module installs automatically.
4. Open the OFFY Connector configuration, enable mobile login, and assign
   users the Mobile User group and the required mobile features.
5. Configure Firebase only when push notifications are required; it is off by
   default and no Firebase credential is included in this module.

The module contains no database name, LAN address, test user, API key, or
customer-specific configuration. Each installation creates its own settings,
users, API keys, and refresh-token records.

## Auth model
- **Access token** — an Odoo API key (`res.users.apikeys`, scope `mobile_api`),
  lifetime = OFFY Connector *Session Timeout* (default 60 min). Sent as `Authorization: Bearer <token>`.
- **Refresh token** — stored hashed in `mobile.refresh.token` (SHA-256, only a
  short index prefix kept in clear), 30 days, **rotated** on every refresh.
- Eligibility is enforced through the connector: the user must be in
  `group_mobile_user`, and `mobile.config` must allow login (not in maintenance).

## Authentication endpoints

### `POST /api/mobile/v1/auth/login`
Body: `{ "login": "...", "password": "..." }`
Returns: `token`, `refreshToken`, `user`, `expiresAt`, `refreshExpiresAt`.

### `POST /api/mobile/v1/auth/refresh`
Body: `{ "refreshToken": "..." }` (or header `X-Refresh-Token`).
Rotates both tokens; the old refresh token is revoked immediately.

### `POST /api/mobile/v1/auth/logout`
Header: `Authorization: Bearer <access token>`. Optional body `refreshToken`.
Revokes the access key and refresh token(s).

Other mobile routes use the same JSON envelope and the access token in the
`Authorization: Bearer <token>` header. Sensitive download routes, including
payslip and log-note attachment files, re-check the caller's access before
streaming; their URLs are not public signed links.

Response envelope: `{ "success": bool, "message": str, "code": str,
"data": {...} }`.

## Odoo 19 notes
- `session.authenticate(env, credential)` takes `env` (not `db`) in 19.
- Access keys use `res.users.apikeys._generate(scope, name, expiration_date)` and
  are validated with `_check_credentials(scope=, key=)`.

## Copying the database (staging, or handing it to someone else)

Mobile authentication material survives a `pg_dump`, so a copy of this database
lets whoever holds it act as an already-signed-in employee. Before a copy
leaves this machine:

```bash
odoo-bin neutralize -d <copy_of_database>
```

`data/neutralize.sql` clears, for this module:

| What | Effect |
|---|---|
| `mobile.refresh.token` (and its company m2m, via `ON DELETE CASCADE`) | emptied |
| `res.users.apikeys` rows with `scope = 'mobile_api'` | deleted |

Access tokens are **core** `res.users.apikeys` rows rather than a table of
ours, which is why they need explicit handling here — the same reason
`uninstall_hook()` in `__init__.py` exists. The delete is scoped to
`mobile_api`, so API keys the customer created for any other integration are
untouched; `tests/test_neutralize.py` asserts both halves of that.

The file is picked up automatically by module name
(`odoo/modules/neutralize.py`) and is deliberately **not** listed in the
manifest's `data` key — it must never run at install or upgrade.

## Author
Odox SoftHub LLP — https://odoxsofthub.com/

## Licence

LGPL-3 (Copyright (C) 2026 Odox SoftHub LLP). See [`LICENSE`](LICENSE).
