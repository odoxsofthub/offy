from odoo.http import request

from . import main


class MobileApiUser(main.MobileApiAuth):
    """User access details endpoint for the mobile app."""

    def _feature_payload(self, user):
        """Delegates to the shared builder on `mobile.sync.service`, which the websocket also uses.
        Kept as the documented extension point; do not add a second builder."""
        return request.env["mobile.sync.service"]._feature_payload(user)

    @main.http.route("/api/mobile/v1/company", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def company_list(self, **kwargs):
        """List the user's allowed companies with the default and current selection."""
        user, err = self._authenticate_mobile(with_company_context=False)
        if err:
            return err
        uid = user.id
        selected_ids = self._get_company_context(uid)
        selected_company = request.env["res.company"].sudo().browse(
            selected_ids[:1]
        )

        companies = [{
            "id": company.id,
            "name": company.name,
            "currency": {
                "id": company.currency_id.id,
                "name": company.currency_id.name,
                "symbol": company.currency_id.symbol,
            },
        } for company in request.env["res.company"].sudo().browse(
            self._employment_company_ids(user))]

        default_company = user.sudo().company_id
        return self._json(success=True, message="Companies", data={
            "default_company_id": default_company.id,
            "default_company_currency": {
                "id": default_company.currency_id.id,
                "name": default_company.currency_id.name,
                "symbol": default_company.currency_id.symbol,
            },
            "selected_company_ids": selected_ids,
            "selected_company_id": selected_company.id or None,
            "selected_company_name": selected_company.name or None,
            "company_session_id": (request.httprequest.headers.get(
                "X-Mobile-Session", "") or "").strip() or None,
            "companies": companies,
        })

    @main.http.route("/api/mobile/v1/user/access-details", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def user_access_details(self, **kwargs):
        user, err = self._authenticate_mobile(with_company_context=False)
        if err:
            return err
        uid = user.id

        # Company context from the active refresh token (multi-company).
        company_ids = self._get_company_context(uid)
        request.update_context(allowed_company_ids=company_ids)
        selected_company = request.env.company

        config = request.env["mobile.config"].sudo().search([], limit=1)

        data = {
            "user": {
                "id": user.id,
                "name": user.name,
                "login": user.login,
                "active": user.active,
                "mobile_user": user.sudo().has_group(
                    "odx_mobile_connector.group_mobile_user"
                ),
            },
            "company": {
                "selected_company_id": selected_company.id,
                "selected_company_name": selected_company.name,
                "selected_company_currency": {
                    "id": selected_company.currency_id.id,
                    "name": selected_company.currency_id.name,
                    "symbol": selected_company.currency_id.symbol,
                },
                # The default company is kept separately for backward compatibility.
                "default_company_id": user.sudo().company_id.id,
                "default_company_currency": {
                    "id": user.sudo().company_id.currency_id.id,
                    "name": user.sudo().company_id.currency_id.name,
                    "symbol": user.sudo().company_id.currency_id.symbol,
                },
            },
            "config": {
                "login_enabled": config.login_enabled if config else True,
                "maintenance_mode": config.maintenance_mode if config else False,
                "max_devices": config.max_devices if config else 1,
                "push_notifications_enabled": (
                    config.push_notifications_enabled if config else True
                ),
            },
            "features": self._feature_payload(user),
        }
        return self._json(success=True, message="User access details", data=data)
