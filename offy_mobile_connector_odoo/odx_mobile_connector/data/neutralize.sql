-- Neutralization for odx_mobile_connector.
--
-- Picked up automatically by `odoo-bin neutralize` for every installed module
-- (odoo/modules/neutralize.py -> get_neutralization_queries reads
-- "<module>/data/neutralize.sql"). It is deliberately NOT listed in the
-- manifest's "data" key: this file must never run at install or upgrade, only
-- when an administrator explicitly neutralizes a copy of the database.
--
-- Purpose: a database copy handed to a third party (or restored into a staging
-- box) must not carry the production Firebase credential, and must not hold
-- credentials that can reach real employees' phones.

-- Firebase service account credential.
-- `firebase_service_account_file` is a fields.Binary declared with
-- attachment=False (models/mobile_config.py), so the private key lives inline
-- in this column as bytea -- there is no ir_attachment row to clean up.
-- The derived metadata columns are cleared too: they are extracted from the
-- JSON on write and would otherwise still name the production project.
--
-- `push_notifications_enabled` is switched off in the same statement on
-- purpose. _check_firebase_credentials_present() (an @api.constrains on
-- mobile.config) forbids "push enabled with no credential", so leaving the
-- flag on would make the record fail validation the first time an admin saves
-- the settings form. This mirrors action_clear_firebase_credentials().
UPDATE mobile_config
   SET firebase_service_account_file = NULL,
       firebase_service_account_filename = NULL,
       firebase_project_id = NULL,
       firebase_client_email = NULL,
       firebase_token_uri = NULL,
       firebase_validation_status = NULL,
       firebase_validation_message = NULL,
       firebase_last_validation_date = NULL,
       push_notifications_enabled = false;

-- Firebase device registration tokens.
-- `firebase_id` is the FCM registration token of a real handset: anyone
-- holding it plus a credential can push to that device.
DELETE FROM mobile_device_token;

-- Mobile login sessions. mobile_device_token.session_id references this table
-- ON DELETE CASCADE, so this also clears any token rows created after the
-- statement above.
DELETE FROM mobile_user_session;

-- Short-lived websocket authentication tickets for the realtime channel.
DELETE FROM mobile_realtime_ticket;

-- Push notification history. Holds the rendered title/message/data_json of
-- notifications about named employees (leave approvals, payslips, expenses),
-- and any rows still queued would be dispatched by the one-minute cron on the
-- machine that restores this database.
DELETE FROM mobile_notification_log;
