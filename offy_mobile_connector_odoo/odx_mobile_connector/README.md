# OFFY Connector

Foundation/configuration layer for a Flutter mobile application built on Odoo
19. The bundled `odx_mobile_api` module adds the Enterprise Payroll-dependent
mobile APIs automatically during installation.

This module delivers the configuration, access, device, session, realtime and
push-notification foundation required by the mobile app. It intentionally keeps
business REST APIs in the separate `odx_mobile_api` module, which Odoo
automatically installs with this connector.

## Installation

1. Copy both `odx_mobile_connector` and `odx_mobile_api` to a directory on the
   Odoo 19 Enterprise server's `addons_path`. Ensure the Enterprise addons
   directory is also on `addons_path`.
2. Update the Apps List and install **OFFY Connector**. The API installs
   automatically in the same operation.
3. If a required module is missing, Odoo refuses the install and names it --
   on a server without Enterprise Payroll the message is
   `You try to install module "odx_mobile_api" that depends on module "hr_payroll".`
   Add the Odoo 19 Enterprise addons directory to `addons_path`, restart,
   update the Apps List and install again.
4. Configure mobile login and user features from the OFFY Connector menus.

No Firebase service-account data, database name, network address, employee, or
test user is included. Push notifications are disabled by default and can be
configured per target installation.

## Models, security and extending

See the technical reference in [`../README.md`](../README.md) for the data model,
security groups, scheduled actions, realtime and push design, and how to add a feature.

## Copying the database (staging, or handing it to someone else)

This module stores a **Google service-account private key** — the Firebase
credential in `mobile.config` — directly in the `mobile_config` table
(`fields.Binary(attachment=False)`), plus FCM registration tokens for real
handsets in `mobile.device.token`. A plain `pg_dump` carries all of it.

Before a copy leaves this machine, neutralize it:

```bash
odoo-bin neutralize -d <copy_of_database>
```

`data/neutralize.sql` clears, for this module:

| What | Effect |
|---|---|
| Firebase service-account file, filename, project id, client email, token uri, validation state | set to `NULL` |
| `push_notifications_enabled` | set to `false` |
| `mobile.device.token` | emptied |
| `mobile.user.session` | emptied |
| `mobile.realtime.ticket` | emptied |
| `mobile.notification.log` | emptied |

Push is switched off in the same statement as the credential on purpose:
`_check_firebase_credentials_present` forbids "push enabled with no
credential", so clearing only the file would leave a record that raises the
first time an administrator saves the settings form.

The file is picked up automatically by module name
(`odoo/modules/neutralize.py`) and is deliberately **not** listed in the
manifest's `data` key — it must never run at install or upgrade, only when an
administrator explicitly neutralizes a copy.

Two things neutralize does **not** do:

* it does not rotate the leaked key — revoke the old service account in Google
  Cloud Console once a dump containing it has left your control;
* it does not reset the attendance geofence. The coordinates in `mobile.config`
  are this deployment's office, so GPS-gated check-ins on a restored copy will
  fail against the wrong fence until they are changed under
  **Settings → OFFY Connector → Attendance**. That is configuration, not a
  credential, so it is left for a human to decide.

`tests/test_neutralize.py` covers this, including a guard that fails the build
when a new `firebase_*` field is added without being classified as either a
credential (scrub it) or a delivery setting (keep it).

## Author

Odox SoftHub LLP — https://odoxsofthub.com/

## Licence

LGPL-3 (Copyright (C) 2026 Odox SoftHub LLP). See [`LICENSE`](LICENSE).
