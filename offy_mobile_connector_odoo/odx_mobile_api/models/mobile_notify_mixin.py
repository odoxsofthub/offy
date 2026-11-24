import logging

from odoo import models

from ..notifications import title_with_company

_logger = logging.getLogger(__name__)


class MobileNotifyMixin(models.AbstractModel):
    """Shared guards for queueing a mobile push from a business record.
    Requires a linked mobile user with the feature enabled, and never breaks the business transaction."""

    _name = "mobile.notify.mixin"
    _description = "Mobile Push Notification Trigger Helper"

    def _mobile_user_for_employee(self, employee, feature_code):
        """Return the user to notify, or an empty recordset if none qualifies.
        sudo() only reads ``mobile.feature``/``mobile.user.feature`` config, never employee or user data."""
        user = employee.user_id if employee else False
        if not user:
            return self.env["res.users"]
        if not user.sudo().has_group("odx_mobile_connector.group_mobile_user"):
            return self.env["res.users"]

        feature = self.env["mobile.feature"].sudo().search(
            [("code", "=", feature_code), ("active", "=", True)], limit=1
        )
        if not feature:
            return self.env["res.users"]
        linked = self.env["mobile.user.feature"].sudo().search_count(
            [("user_id", "=", user.id), ("feature_id", "=", feature.id)]
        )
        return user if linked else self.env["res.users"]

    def _sync_mobile_home(self, employee, sections, reason=False):
        """Silently tell the employee's devices that home sections went stale. Never raises.
        Separate from the user-facing push; some events want only the sync."""
        try:
            user = employee.user_id if employee else False
            if not user:
                return
            self.env["mobile.sync.service"].notify_home(
                user, sections, reason=reason)
        except Exception:
            _logger.exception(
                "Failed to send mobile home sync (model=%s, id=%s).",
                self._name, self.id,
            )

    def _sync_mobile_home_for_users(self, users, sections, reason=False):
        """Sync a set of users directly, for content not scoped to one employee."""
        try:
            if not users:
                return
            self.env["mobile.sync.service"].notify_home(
                users, sections, reason=reason)
        except Exception:
            _logger.exception(
                "Failed to send mobile home sync (model=%s).", self._name)

    def _sync_mobile_home_for_employees(self, employees, sections, reason=False):
        """Sync several employees at once, de-duplicated.
        Used when a write moves a record between employees, so both home cards refresh."""
        try:
            users = employees.mapped("user_id")
            if not users:
                return
            self.env["mobile.sync.service"].notify_home(
                users, sections, reason=reason)
        except Exception:
            _logger.exception(
                "Failed to send mobile home sync (model=%s).", self._name)

    def _mobile_notification_company(self, employee):
        """The company a notification about this record belongs to: its own, else the employee's.
        Returns an empty recordset rather than raising, so an approval never fails over a label."""
        Company = self.env["res.company"]
        try:
            if "company_id" in self._fields:
                company = self.sudo().company_id
                if company:
                    return company
            if employee:
                return employee.sudo().company_id
        except Exception:
            _logger.exception(
                "Failed to resolve notification company (model=%s, id=%s).",
                self._name, self.id,
            )
        return Company

    def _queue_mobile_notification(self, employee, feature_code, notification_type,
                                   title, body, data=None, dedup_key=None):
        """Queue one push for *employee*; return True if queued. Never raises.
        Always attaches ``data.company_*``; the title is company-labelled only for multi-company users."""
        try:
            user = self._mobile_user_for_employee(employee, feature_code)
            if not user:
                return False
            payload = dict(data or {})
            payload.setdefault("type", notification_type)
            payload.setdefault("feature", feature_code)

            company = self._mobile_notification_company(employee)
            if company:
                payload.setdefault("company_id", company.id)
                payload.setdefault("company_name", company.name)
                if user._mobile_is_multi_company():
                    title = title_with_company(title, company.name)

            self.env["mobile.push.service"].queue_once_to_user(
                user, notification_type, self._name, self.id, title, body,
                data=payload, dedup_key=dedup_key,
            )
            return True
        except Exception:
            _logger.exception(
                "Failed to queue mobile notification (type=%s, model=%s, id=%s).",
                notification_type, self._name, self.id,
            )
            return False
