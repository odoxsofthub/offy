from odoo.http import request

from . import main
from .main import API_KEY_SCOPE


class MobileApiContent(main.MobileApiAuth):
    """Read-only Privacy Policy, Terms and FAQ endpoints; global content, so no mobile.feature gate.
    Reads run under the mobile user's own read ACL (no sudo), filtered to published/active records.
    """

    def _authenticate_content(self):
        """Run the shared mobile auth chain; returns (user, None) or (None, error_response)."""
        token = self._bearer_token()
        if not token:
            return None, self._json(
                success=False, code="missing_access_token",
                message="Missing access token", status=401)
        uid = request.env["res.users.apikeys"].sudo()._check_credentials(
            scope=API_KEY_SCOPE, key=token)
        if not uid:
            return None, self._json(
                success=False, code="invalid_access_token",
                message="Invalid access token", status=401)

        request.update_env(user=uid)
        user = request.env.user
        if not user.active:
            return None, self._json(
                success=False, code="user_inactive",
                message="User is inactive", status=403)

        ok, message = self._check_mobile_access(user)
        if not ok:
            return None, self._json(
                success=False, code="mobile_access_denied",
                message=message, status=403)

        # Company context from the active refresh token (multi-company).
        company_ids = self._get_company_context(uid)
        request.update_context(allowed_company_ids=company_ids)
        return user, None

    def _content_document_payload(self, record):
        """Serialize a Privacy Policy / Terms singleton (or ``None``)."""
        if not record:
            return None
        return {
            "id": record.id,
            "title": record.name or "",
            "body": record.body or "",
            "is_published": record.is_published,
            "updated_at": record.write_date,
        }

    def _faq_payload(self, records):
        return [{
            "id": faq.id,
            "title": faq.heading or "",
            "description": faq.sub_heading or "",
        } for faq in records]

    def _published_privacy(self):
        return request.env["mobile.privacy.policy"].sudo().search(
            [("is_published", "=", True)], limit=1)

    def _published_terms(self):
        return request.env["mobile.terms.condition"].sudo().search(
            [("is_published", "=", True)], limit=1)

    def _active_faqs(self):
        return request.env["mobile.faq"].sudo().search(
            [("active", "=", True)], order="sequence, id")

    @main.http.route("/api/mobile/v1/privacy-policy", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def privacy_policy(self, **kwargs):
        _user, error = self._authenticate_content()
        if error:
            return error
        record = self._published_privacy()
        return self._json(
            success=True, message="Privacy policy fetched successfully",
            data={"privacy_policy": self._content_document_payload(record)})

    @main.http.route("/api/mobile/v1/terms-conditions", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def terms_conditions(self, **kwargs):
        _user, error = self._authenticate_content()
        if error:
            return error
        record = self._published_terms()
        return self._json(
            success=True, message="Terms & conditions fetched successfully",
            data={"terms_conditions": self._content_document_payload(record)})

    @main.http.route("/api/mobile/v1/faqs", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def faqs(self, **kwargs):
        _user, error = self._authenticate_content()
        if error:
            return error
        faqs = self._active_faqs()
        return self._json(
            success=True, message="FAQs fetched successfully",
            data={"faqs": self._faq_payload(faqs)})

    @main.http.route("/api/mobile/v1/other-data", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def other_data(self, **kwargs):
        """Convenience aggregate for the app's 'Other Data' screen."""
        _user, error = self._authenticate_content()
        if error:
            return error
        return self._json(
            success=True, message="Other data fetched successfully",
            data={
                "privacy_policy": self._content_document_payload(
                    self._published_privacy()),
                "terms_conditions": self._content_document_payload(
                    self._published_terms()),
                "faqs": self._faq_payload(self._active_faqs()),
            })
