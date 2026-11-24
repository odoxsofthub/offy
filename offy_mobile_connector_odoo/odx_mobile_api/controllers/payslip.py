import logging
import shutil
import subprocess
import tempfile

from odoo.http import content_disposition, request

from . import main
from ..filter_sources import PayslipFilterSource
from .home import _iso_utc
from .main import API_KEY_SCOPE

_logger = logging.getLogger(__name__)

# Payslips in these states are considered "issued" and visible to the employee.
VISIBLE_STATES = ("validated", "paid")

# The category trees the `earnings` / `deductions` summary is built from.
EARNING_CATEGORY_ROOTS = ("BASIC", "ALW")
DEDUCTION_CATEGORY_ROOTS = ("DED",)

# Fallback only: a payslip prints with the report chosen by its salary structure.
PAYSLIP_REPORT = "hr_payroll.action_report_payslip"

# Newest first, with a deterministic tiebreak.
PAYSLIP_ORDER = "date_to desc, date_from desc, id desc"

# How many times to render before giving up and serving whatever came last.
PDF_RENDER_ATTEMPTS = 3
# Real payslip text far exceeds the empty layout's; used to detect blank renders.
PDF_MIN_TEXT_CHARS = 200

# How many earlier payslips the home/latest screen shows beneath the current one.
LATEST_HISTORY_LIMIT = 3


def _iso_date(d):
    return d.isoformat() if d else None


class MobileApiPayslip(main.MobileApiAuth):
    """Payslip / pay-history endpoints for the mobile app."""

    def _authenticate_payslip(self):
        """Shared auth, eligibility and employee resolution; returns (user, error_response)."""
        token = self._bearer_token()
        if not token:
            return None, self._json(success=False, code="missing_access_token",
                                    message="Missing access token", status=401)
        uid = request.env["res.users.apikeys"].sudo()._check_credentials(
            scope=API_KEY_SCOPE, key=token
        )
        if not uid:
            return None, self._json(success=False, code="invalid_access_token",
                                    message="Invalid access token", status=401)

        request.update_env(user=uid)
        user = request.env.user
        if not user.active:
            return None, self._json(success=False, code="user_inactive",
                                    message="User is inactive", status=403)
        ok, message = self._check_mobile_access(user)
        if not ok:
            return None, self._json(success=False, code="mobile_access_denied",
                                    message=message, status=403)

        request.update_context(
            allowed_company_ids=self._get_company_context(uid))
        # Re-bound after the switch: res.users.employee_id depends on the company context.
        user = request.env.user

        if not self._mobile_feature_allowed(user, "payslip"):
            return None, self._json(success=False, code="payslip_access_denied",
                                    message="You do not have permission to view payslips.",
                                    status=403)

        if not user.employee_id:
            return None, self._json(success=False, code="employee_not_linked",
                                    message="No employee is linked to this mobile user.",
                                    status=404)
        return user, None

    def _period_label(self, payslip):
        return payslip.date_from.strftime("%B %Y") if payslip.date_from else payslip.name

    def _payslip_year(self, payslip):
        """Year of a payslip for section headers, from ``date_to`` (the list sort key), else ``date_from``.
        Not ``paid_date``: December payslips paid in January would land in the wrong section."""
        period_end = payslip.date_to or payslip.date_from
        return period_end.year if period_end else None

    def _category_ancestry(self, category):
        """Every category code from *category* up to its root, inclusive.
        Mirrors `_sum_salary_rule_category`, which adds a line to its category and every ancestor."""
        codes = []
        while category:
            codes.append(category.code)
            category = category.parent_id
        return codes

    def _payslip_amount_buckets(self, payslip):
        """`earnings` / `deductions` for one payslip, matched by category ancestry (BASIC/ALW vs DED) like NET.
        Aggregates and title rows are excluded; if nothing matches, falls back to the amount's sign."""
        printed = payslip.line_ids.filtered(
            lambda l: l.appears_on_payslip and not l.salary_rule_id.title)

        def in_tree(line, roots):
            return any(code in roots
                       for code in self._category_ancestry(line.category_id))

        earnings = printed.filtered(lambda l: in_tree(l, EARNING_CATEGORY_ROOTS))
        deductions = printed.filtered(lambda l: in_tree(l, DEDUCTION_CATEGORY_ROOTS))

        if not earnings and not deductions:
            _logger.info(
                "Payslip %s: no line rolls up to %s or %s (structure %s); "
                "falling back to splitting the summary by sign.",
                payslip.id, EARNING_CATEGORY_ROOTS, DEDUCTION_CATEGORY_ROOTS,
                payslip.struct_id.name)
            earnings = printed.filtered(lambda l: l.total > 0)
            deductions = printed.filtered(lambda l: l.total < 0)

        return {
            "earnings": [self._amount_entry(line) for line in earnings],
            "deductions": [self._amount_entry(line) for line in deductions],
        }

    def _amount_entry(self, line):
        return {
            "code": line.code,
            "name": line.name,
            "amount": line.total,
        }

    def _payslip_lines(self, payslip):
        """Every line the printed payslip shows, in the same order as the PDF (``appears_on_payslip``).
        This is the authoritative list; `is_title` rows are headings with no figures."""
        show_ytd = bool(payslip.ytd_computation)
        lines = []
        for line in payslip.line_ids.filtered(lambda l: l.appears_on_payslip):
            rule = line.salary_rule_id
            entry = {
                "sequence": line.sequence,
                "code": line.code,
                "name": line.name,
                "category": {
                    "code": line.category_id.code,
                    "name": line.category_id.name,
                },
                "amount": line.amount,
                "quantity": line.quantity,
                "rate": line.rate,
                "total": line.total,
                # A heading row: printed as text only, never as a figure.
                "is_title": bool(rule.title),
            }
            if show_ytd:
                entry["ytd"] = line.ytd
            lines.append(entry)
        return lines

    def _payslip_filename(self, payslip):
        return "Payslip_%s.pdf" % payslip.id

    def _payslip_download_url(self, payslip):
        """Bearer-authenticated `/file` URL for this payslip PDF; the route repeats all access checks."""
        return "%s/api/mobile/v1/payslip/%s/file" % (
            self._api_base_url(), payslip.id)

    def _payslip_report(self, payslip):
        """Report renderer pinned to the payslip's company and language, never the caller's.
        `sudo()` is required: the template reads `hr.group_hr_user`-only employee fields."""
        payslip = payslip.sudo()
        employee = payslip.employee_id
        lang = (employee.lang
                or payslip.company_id.partner_id.lang
                or "en_US")
        return request.env["ir.actions.report"].sudo().with_context(
            lang=lang,
            allowed_company_ids=payslip.company_id.ids,
        ).with_company(payslip.company_id)

    def _payslip_report_action(self, payslip):
        """The report the backend prints for this payslip: the structure's `report_id`, else the generic one.
        `sudo()` reads only structure configuration, which has no employee ACL; may return an empty recordset."""
        report = payslip.sudo().struct_id.report_id
        if report:
            return report
        return payslip.env.ref(PAYSLIP_REPORT, raise_if_not_found=False) \
            or payslip.env["ir.actions.report"]

    def _pdf_has_visible_text(self, pdf_content):
        """Whether a rendered PDF shows its text (True/False, or None if `pdftotext` is unavailable).
        Guards an intermittent wkhtmltopdf font race that yields valid PDFs with blank text cells."""
        binary = shutil.which("pdftotext")
        if not binary:
            return None
        try:
            with tempfile.NamedTemporaryFile(suffix=".pdf") as handle:
                handle.write(pdf_content)
                handle.flush()
                result = subprocess.run(
                    [binary, handle.name, "-"],
                    capture_output=True, timeout=20, check=False,
                )
        except Exception:
            # Never let the *check* break the download it is meant to protect.
            _logger.exception("Payslip PDF text check failed to run.")
            return None
        if result.returncode != 0:
            return None
        text = (result.stdout or b"").decode("utf-8", "replace")
        # The empty layout alone yields only the company name and page number, far below this.
        return len("".join(text.split())) > PDF_MIN_TEXT_CHARS

    def _render_payslip_pdf(self, payslip):
        """Render the payslip PDF, retrying when text is missing; returns (pdf_bytes, error_response).
        If every attempt is blank, the last render is still returned rather than an error."""
        report_action = self._payslip_report_action(payslip)
        if not report_action:
            _logger.error(
                "No payslip report could be resolved (payslip=%s, structure=%s); "
                "neither the structure's template nor %s exists.",
                payslip.id, payslip.sudo().struct_id.id, PAYSLIP_REPORT)
            return None, self._json(
                success=False, code="pdf_generation_failed",
                message="Unable to generate the payslip PDF at this time.",
                status=500)

        pdf_content = None
        for attempt in range(1, PDF_RENDER_ATTEMPTS + 1):
            try:
                pdf_content, _ = self._payslip_report(payslip)._render_qweb_pdf(
                    report_action, [payslip.id]
                )
            except Exception:
                # e.g. wkhtmltopdf missing on the server; never leak the error to the client.
                _logger.exception(
                    "Payslip PDF render failed for payslip=%s uid=%s",
                    payslip.id, request.env.uid)
                return None, self._json(
                    success=False, code="pdf_generation_failed",
                    message="Unable to generate the payslip PDF at this time.",
                    status=500)

            if self._pdf_has_visible_text(pdf_content) is False:
                _logger.warning(
                    "Payslip PDF rendered with no visible text "
                    "(payslip=%s, attempt %s/%s); re-rendering.",
                    payslip.id, attempt, PDF_RENDER_ATTEMPTS)
                continue
            return pdf_content, None

        _logger.error(
            "Payslip PDF still had no visible text after %s attempts "
            "(payslip=%s); serving the last render.",
            PDF_RENDER_ATTEMPTS, payslip.id)
        return pdf_content, None

    def _payslip_summary(self, payslip):
        file_url = self._payslip_download_url(payslip)
        return {
            "id": payslip.id,
            "period": self._period_label(payslip),
            # Section key for the year-grouped history list.
            "year": self._payslip_year(payslip),
            "date_from": _iso_date(payslip.date_from),
            "date_to": _iso_date(payslip.date_to),
            "net_pay": main.amount_2dp(payslip.net_wage),
            "state": payslip.state,
            # This payslip's own payment date, straight from Odoo's paid_date.
            "payment_date": _iso_date(payslip.paid_date),
            "filename": self._payslip_filename(payslip),
            # Same field name used by log-note attachments.
            "url": file_url,
            # Compatibility alias kept for older mobile clients.
            "download_url": file_url,
            "download_requires_auth": True,
        }

    @main.http.route("/api/mobile/v1/payslip", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def payslip_latest(self, **kwargs):
        user, err = self._authenticate_payslip()
        if err:
            return err
        employee = user.employee_id

        # Only the current payslip plus the short history strip are ever shown, so the query is capped.
        payslips = request.env["hr.payslip"].sudo().search([
            ("employee_id", "=", employee.id),
            ("state", "in", VISIBLE_STATES),
            ("employee_id.company_id", "in", self._allowed_company_ids()),
        ], order=PAYSLIP_ORDER, limit=LATEST_HISTORY_LIMIT + 1)

        if not payslips:
            return self._json(success=True, message="No payslips found", data={
                "latest": None,
                "history": [],
            })

        latest = payslips[0]

        data = self._payslip_summary(latest)
        # Same keys, built the same way, as `/payslip/<id>`, so the home card matches the detail screen.
        data["lines"] = self._payslip_lines(latest)
        data.update(self._payslip_amount_buckets(latest))
        # `[1:]`: the current payslip is already served as `latest`.
        data["history"] = [self._payslip_summary(p) for p in payslips[1:]]

        return self._json(success=True, message="Payslip fetched successfully",
                          data=data)

    def _payslip_years(self, domain):
        """Every year the caller has a visible payslip in, newest first, via one grouped query.
        Grouped on `date_to:year` to agree with `_payslip_year()` and the list ordering."""
        rows = request.env["hr.payslip"].sudo()._read_group(
            domain, groupby=["date_to:year"], aggregates=["__count"],
        )
        years = []
        for period, count in rows:
            # The year bucket can be None (no date_to); skip it.
            if not period:
                continue
            years.append({"year": period.year, "count": count})
        years.sort(key=lambda row: row["year"], reverse=True)
        return years

    @main.http.route("/api/mobile/v1/payslip/list", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def payslip_list(self, **kwargs):
        """Paginated payslip history ordered by `date_to desc`; optional `year` filter, `page_size` max 50.
        The list stays flat so year sections merge across pages; `years` indexes all years with counts."""
        user, err = self._authenticate_payslip()
        if err:
            return err
        employee = user.employee_id

        try:
            page = int(kwargs.get("page", 1))
            page_size = int(kwargs.get("page_size", 10))
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_pagination",
                              message="page and page_size must be integers.",
                              status=400)
        if page < 1 or page_size < 1:
            return self._json(success=False, code="invalid_pagination",
                              message="page and page_size must be >= 1.",
                              status=400)
        page_size = min(page_size, 50)

        domain = [
            ("employee_id", "=", employee.id),
            ("state", "in", VISIBLE_STATES),
            ("employee_id.company_id", "in", self._allowed_company_ids()),
        ]
        # Stored source=payslip filters apply implicitly; this route takes no filter parameters.
        payslip_source = PayslipFilterSource(user)
        payslip_filters = request.env["mobile.list.filter"].get_state(
            user, payslip_source.code)

        # `years` reflects the UNFILTERED history so the year picker never hides its own way out.
        years = self._payslip_years(domain)

        year_filter = kwargs.get("year")
        if year_filter not in (None, ""):
            try:
                year_filter = int(year_filter)
            except (TypeError, ValueError):
                return self._json(success=False, code="invalid_year",
                                  message="year must be an integer.",
                                  status=400)
            # Bounded before the ORM: date(year, 1, 1) raises on out-of-range years.
            if not 1900 <= year_filter <= 2999:
                return self._json(success=False, code="invalid_year",
                                  message="year is out of range.", status=400)
            domain += [
                ("date_to", ">=", "%d-01-01" % year_filter),
                ("date_to", "<=", "%d-12-31" % year_filter),
            ]
        else:
            year_filter = None

        domain += payslip_source.domain_from_state(payslip_filters)

        # `?search=` is transient and never stored; applied AFTER `years` so it cannot hide the picker.
        search_term = (kwargs.get("search") or "").strip()
        if search_term:
            domain += payslip_source.search_domain(search_term)

        payslip_model = request.env["hr.payslip"].sudo()
        total = payslip_model.search_count(domain)
        payslips = payslip_model.search(
            domain, order=PAYSLIP_ORDER,
            limit=page_size, offset=(page - 1) * page_size,
        )

        total_pages = (total + page_size - 1) // page_size if total else 0
        return self._json(success=True, message="Payslips fetched successfully", data={
            "payslips": [self._payslip_summary(p) for p in payslips],
            # Every year with at least one visible payslip, newest first.
            "years": years,
            "year": year_filter,
            "pagination": {
                "page": page,
                "page_size": page_size,
                "total": total,
                "total_pages": total_pages,
            },
        })

    @main.http.route("/api/mobile/v1/payslip/<payslip_id>", type="http",
                     auth="none", methods=["GET"], csrf=False)
    def payslip_detail(self, payslip_id, **kwargs):
        # Not `<int:payslip_id>`: the int converter would 404 non-numeric ids instead of our JSON 400.
        try:
            payslip_id = int(payslip_id)
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_payslip_id",
                              message="payslip_id must be an integer.",
                              status=400)

        user, err = self._authenticate_payslip()
        if err:
            return err
        employee = user.employee_id

        payslip = request.env["hr.payslip"].sudo().search([
            ("id", "=", payslip_id),
            ("employee_id", "=", employee.id),
            ("state", "in", VISIBLE_STATES),
            ("employee_id.company_id", "in", self._allowed_company_ids()),
        ], limit=1)
        if not payslip:
            return self._json(success=False, code="payslip_not_found",
                              message="Payslip not found.", status=404)

        data = self._payslip_summary(payslip)
        data["lines"] = self._payslip_lines(payslip)
        data.update(self._payslip_amount_buckets(payslip))
        return self._json(success=True, message="Payslip fetched successfully",
                          data=data)

    @main.http.route("/api/mobile/v1/payslip/<payslip_id>/download",
                     type="http", auth="none", methods=["GET"], csrf=False)
    def payslip_download(self, payslip_id, **kwargs):
        """Legacy raw-PDF alias of `/file`, kept so older clients do not hit a dead URL."""
        return self.payslip_file(payslip_id, **kwargs)

    @main.http.route("/api/mobile/v1/payslip/<payslip_id>/file",
                     type="http", auth="none", methods=["GET"], csrf=False)
    def payslip_file(self, payslip_id, **kwargs):
        """Stream one authorised employee payslip as a PDF after the usual ownership checks."""
        try:
            payslip_id = int(payslip_id)
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_payslip_id",
                              message="payslip_id must be an integer.", status=400)

        user, err = self._authenticate_payslip()
        if err:
            return err
        payslip = request.env["hr.payslip"].sudo().search([
            ("id", "=", payslip_id),
            ("employee_id", "=", user.employee_id.id),
            ("state", "in", VISIBLE_STATES),
            ("employee_id.company_id", "in", self._allowed_company_ids()),
        ], limit=1)
        if not payslip:
            return self._json(success=False, code="payslip_not_found",
                              message="Payslip not found.", status=404)

        pdf_content, error = self._render_payslip_pdf(payslip)
        if error:
            return error
        return request.make_response(pdf_content, headers=[
            ("Content-Type", "application/pdf"),
            ("Content-Length", str(len(pdf_content))),
            ("Content-Disposition", content_disposition(
                self._payslip_filename(payslip))),
            ("Cache-Control", "private, no-store"),
        ])
