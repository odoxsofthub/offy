"""Source-scoped list filters: options, values and apply routes dispatched by `source` and `option` query params.
New filters are new cases in `filter_sources.py`, not new URLs; filters are stored per user/source in `mobile.list.filter`.
"""

import json
import logging

from odoo.exceptions import AccessError
from odoo.http import request

from . import main
from ..filter_sources import FILTER_SOURCES, FilterError

_logger = logging.getLogger(__name__)


class MobileApiFilters(main.MobileApiAuth):
    """Dispatchers for the filter value-lists, the menu, and applying."""

    def _resolve_source(self, kwargs):
        """Authenticate, then resolve `source`; returns (source, None) or (None, error_response).
        Uses the source's own feature gate so the filter route cannot bypass per-user feature switches.
        """
        user, err = self._authenticate_mobile()
        if err:
            return None, err

        source_code = (kwargs.get("source") or "").strip()
        if not source_code:
            return None, self._json(
                success=False, code="missing_source",
                message="source is required.", status=400)
        source_class = FILTER_SOURCES.get(source_code)
        if not source_class:
            return None, self._json(
                success=False, code="unknown_source",
                message="Unknown filter source: %s. Available: %s."
                        % (source_code, ", ".join(sorted(FILTER_SOURCES))),
                status=404)

        # A multi-list source must be told which list; any default would silently filter the wrong one.
        view = (kwargs.get("view") or "").strip()
        if source_class.VIEWS:
            if not view:
                return None, self._json(
                    success=False, code="missing_view",
                    message="view is required for source '%s'. Available: %s."
                            % (source_code, ", ".join(source_class.VIEWS)),
                    status=400)
            if view not in source_class.VIEWS:
                return None, self._json(
                    success=False, code="unknown_view",
                    message="Unknown view '%s' for source '%s'. Available: %s."
                            % (view, source_code, ", ".join(source_class.VIEWS)),
                    status=404)
        else:
            # Single-list sources ignore `view` so a client that always sends it keeps working.
            view = ""

        if not self._mobile_feature_allowed(user, source_class.feature):
            return None, self._json(
                success=False, code="filter_access_denied",
                message="You do not have permission to use this list.",
                status=403)
        if not user.employee_id:
            return None, self._json(
                success=False, code="employee_not_linked",
                message="No employee is linked to this mobile user.",
                status=404)
        return source_class(user, view), None

    def _resolve_option(self, source, kwargs, allowed):
        """Resolve `option` against *allowed*: the menu uses MENU_OPTIONS, apply accepts the wider OPTIONS (adds date_range)."""
        option = (kwargs.get("option") or "").strip()
        if not option:
            return None, self._json(
                success=False, code="missing_option",
                message="option is required.", status=400)
        if option not in allowed:
            return None, self._json(
                success=False, code="unknown_option",
                message="Unknown filter option '%s' for source '%s'. "
                        "Available: %s." % (option, source.code,
                                            ", ".join(allowed)),
                status=404)
        return option, None

    @staticmethod
    def _option_url(source, option):
        suffix = "&view=%s" % source.view if source.view else ""
        return "/api/mobile/v1/filters?source=%s%s&option=%s" % (
            source.code, suffix, option)

    @staticmethod
    def _apply_url(source):
        suffix = "&view=%s" % source.view if source.view else ""
        return "/api/mobile/v1/filters/apply?source=%s%s" % (source.code, suffix)

    def _filter_error(self, error):
        return self._json(success=False, code=error.code,
                          message=error.message, status=error.status)

    @main.http.route("/api/mobile/v1/filters/options", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def filter_options(self, **kwargs):
        """The filter dimensions for *source*, each with a ready-made values URL so the app never composes URLs itself."""
        source, err = self._resolve_source(kwargs)
        if err:
            return err

        options = [{
            "option": option,
            "label": source.OPTION_LABELS.get(option, option.title()),
            "selection": source.OPTION_SELECTION.get(option, "multi"),
            "url": self._option_url(source, option),
        } for option in source.MENU_OPTIONS]

        state = request.env["mobile.list.filter"].get_state(
            source.user, source.code, source.view)
        return self._json(
            success=True, message="Filter options fetched successfully",
            data={
                "source": source.code,
                "view": source.view or None,
                "options": options,
                "apply_url": self._apply_url(source),
                "active": source.active_payload(state),
            })

    @main.http.route("/api/mobile/v1/filters", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def filter_values(self, **kwargs):
        """Values for one filter dimension; the shape is per option and echoes `option`.
        `category` returns a flat item list; `month` returns buckets, or the months inside `bucket`.
        """
        source, err = self._resolve_source(kwargs)
        if err:
            return err
        option, err = self._resolve_option(source, kwargs, source.MENU_OPTIONS)
        if err:
            return err

        try:
            data = getattr(source, "values_%s" % option)(kwargs)
        except FilterError as error:
            return self._filter_error(error)
        except AccessError:
            return self._json(
                success=False, code="filter_access_denied",
                message="You do not have permission to view these values.",
                status=403)

        data["source"] = source.code
        data["view"] = source.view or None
        return self._json(success=True,
                          message="Filter values fetched successfully",
                          data=data)

    @main.http.route("/api/mobile/v1/filters/apply", type="http", auth="none",
                     methods=["POST"], csrf=False, readonly=False)
    def filter_apply(self, **kwargs):
        """Apply or clear one filter dimension; null, an omitted key or an empty list all clear it.
        `month` and `date_range` are mutually exclusive, and the response reports the full active state.
        """
        source, err = self._resolve_source(kwargs)
        if err:
            return err
        option, err = self._resolve_option(source, kwargs, source.OPTIONS)
        if err:
            return err

        # _payload() maps any non-object body to {} (= clear the filter), so no malformed-body branch.
        payload = self._payload()

        try:
            key, value, clears = getattr(source, "apply_%s" % option)(payload)
        except FilterError as error:
            return self._filter_error(error)

        state = request.env["mobile.list.filter"].set_option(
            source.user, source.code, key, value, clears=clears,
            view=source.view)

        return self._json(
            success=True,
            message=("Filter cleared successfully" if value is None
                     else "Filter applied successfully"),
            data={
                "source": source.code,
                "view": source.view or None,
                "option": option,
                "cleared": value is None,
                "active": source.active_payload(state),
            })
