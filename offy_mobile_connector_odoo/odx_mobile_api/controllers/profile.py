import base64
import logging
import mimetypes

from odoo.exceptions import AccessError
from odoo.http import request

from . import main
# Attachment "kind" buckets are defined once in log_note.py and reused here.
from .log_note import (
    ATTACHMENT_KIND_BY_PREFIX,
    ATTACHMENT_KIND_FILE,
    ATTACHMENT_KIND_PDF,
)
from .main import API_KEY_SCOPE

_logger = logging.getLogger(__name__)


# Longest edge of an image preview, in pixels.
IMAGE_PREVIEW_MAX_PX = 1024
IMAGE_PREVIEW_QUALITY = 80

# A card shows a few lines; a multi-megabyte log must not cross the wire.
TEXT_PREVIEW_MAX_BYTES = 8 * 1024

TEXT_PREVIEW_MIMETYPES = ("text/", "application/json", "application/xml")
TEXT_PREVIEW_EXTENSIONS = (".txt", ".csv", ".json", ".xml", ".md", ".log", ".yml", ".yaml")


def _extract_pdf_page(attachment, index=0):
    """First page of a PDF attachment, or None.
    Imported lazily and guarded: a failing module-level pypdf import would 404 every mobile endpoint."""
    try:
        from odoo.tools.pdf import extract_page  # noqa: PLC0415
        return extract_page(attachment, index)
    except Exception:
        _logger.info(
            "PDF page extraction unavailable for attachment %s.", attachment.id)
        return None


def _resize_image(raw_bytes):
    """Downscaled copy of an image (raw bytes in and out, not base64), or None.
    ``verify_resolution=False`` so large photos still get a preview."""
    try:
        from odoo.tools.image import image_process  # noqa: PLC0415
        return image_process(
            raw_bytes,
            size=(IMAGE_PREVIEW_MAX_PX, IMAGE_PREVIEW_MAX_PX),
            quality=IMAGE_PREVIEW_QUALITY,
            verify_resolution=False,
        )
    except Exception:
        _logger.info("Image preview generation failed.")
        return None

# hr_presence_state values that count as "online" for the mobile app.
ONLINE_PRESENCE_STATES = ("present",)

AVATAR_FIELD = "avatar_1920"

# The avatar link scheme (sign / verify / TTL / signature length) lives in main.py.
AVATAR_TOKEN_SCOPE = main.IMAGE_TOKEN_SCOPE
AVATAR_TOKEN_TTL = main.IMAGE_TOKEN_TTL
AVATAR_SIG_LENGTH = main.IMAGE_SIG_LENGTH


def _initials(name):
    if not name:
        return ""
    parts = [p for p in name.split() if p]
    return "".join(p[0] for p in parts[:2]).upper()


def _work_address(employee_public):
    """Single-line address from the employee's work location partner (readable by base.group_user).
    Built by hand because `work_location_name` can return False from a stale compute."""
    partner = employee_public.work_location_id.address_id
    if not partner:
        return None
    parts = [partner.street, partner.street2, partner.city]
    return ", ".join(p for p in parts if p) or None


def _iso_date(value):
    return value.isoformat() if value else None


def _display_date(value):
    return value.strftime("%d %B %Y") if value else None


def _format_address(record, prefix=""):
    if not record:
        return None
    fields = record._fields

    def read(name):
        if prefix:
            name = "%s_%s" % (prefix, name)
        if name not in fields:
            return None
        try:
            return record[name]
        except AccessError:
            return None

    country = read("country_id")
    state = read("state_id")
    parts = [
        read("street"),
        read("street2"),
        read("city"),
        state.name if state else None,
        read("zip"),
        country.name if country else None,
    ]
    return "\n".join(p for p in parts if p) or None


def _format_private_address(values):
    """Format the connector's explicitly exposed private-address values."""
    parts = [
        values.get("private_street"),
        values.get("private_street2"),
        values.get("private_city"),
        values.get("private_state_id"),
        values.get("private_zip"),
        values.get("private_country_id"),
    ]
    return "\n".join(part for part in parts if part) or None


class MobileApiProfile(main.MobileApiAuth):
    """Profile screen: own profile, reporting manager, team members, avatars.
    Reads `hr.employee.public` (record-rule scoped) to avoid ACL errors and the private-field guard."""

    def _authenticate_profile(self):
        """Shared auth and employee resolution; returns (employee_public, token, error_response).
        `token` is the full Bearer token: never put it in a URL (see `_avatar_url`)."""
        token = self._bearer_token()
        if not token:
            return None, None, self._json(success=False, code="missing_access_token",
                                    message="Missing access token", status=401)
        uid = request.env["res.users.apikeys"].sudo()._check_credentials(
            scope=API_KEY_SCOPE, key=token
        )
        if not uid:
            return None, None, self._json(success=False, code="invalid_access_token",
                                    message="Invalid access token", status=401)

        request.update_env(user=uid)
        user = request.env.user
        if not user.active:
            return None, None, self._json(success=False, code="user_inactive",
                                    message="User is inactive", status=403)
        ok, message = self._check_mobile_access(user)
        if not ok:
            return None, None, self._json(success=False, code="mobile_access_denied",
                                    message=message, status=403)

        selected_company_ids = self._get_company_context(uid)
        request.update_context(allowed_company_ids=selected_company_ids)
        # Re-bound after the switch: res.users.employee_id depends on the company context.
        user = request.env.user

        # Resolve "which employee am I" via a direct hr.employee.public search.
        try:
            # A multi-company user has one hr.employee per company, so scope the search to their companies.
            Employee = request.env["hr.employee.public"].with_context(
                allowed_company_ids=user.sudo().company_ids.ids
            )
            employee_public = Employee.search(
                [("user_id", "=", uid),
                 ("company_id", "in", selected_company_ids)], limit=1
            ) or Employee.search(
                [("user_id", "=", uid)], limit=1
            )
        except AccessError:
            return None, None, self._json(success=False, code="employee_not_linked",
                                    message="No employee is linked to this mobile user.",
                                    status=404)
        if not employee_public:
            return None, None, self._json(success=False, code="employee_not_linked",
                                    message="No employee is linked to this mobile user.",
                                    status=404)
        return employee_public, token, None

    def _team_recordset(self, employee_public):
        """"My Team": direct reports if any, else peers sharing your manager, else empty.
        Never falls back to department or company, so the app never gets a full directory."""
        if employee_public.child_ids:
            return employee_public.child_ids
        if employee_public.parent_id:
            return employee_public.parent_id.child_ids - employee_public
        return request.env["hr.employee.public"].browse()

    def _can_view_employee(self, employee_public, target_id):
        """Avatar/detail visibility boundary: self, manager, or team only."""
        allowed_ids = {employee_public.id}
        if employee_public.parent_id:
            allowed_ids.add(employee_public.parent_id.id)
        allowed_ids.update(self._team_recordset(employee_public).ids)
        return target_id in allowed_ids

    def _sign_avatar(self, employee_public, expiry):
        """Avatar-specific alias of `main._sign_image_token`. Unchanged payload."""
        return self._sign_image_token(employee_public, AVATAR_FIELD, expiry)

    def _avatar_url(self, employee_public):
        """Avatar URL with a signed link token scoped to one record, field and expiry.
        Never the Bearer token, which would leak into logs; uses the request host for LAN testing."""
        return "%s/api/mobile/v1/employees/%s/avatar?t=%s" % (
            self._api_base_url(), employee_public.id,
            self._image_link_token(employee_public, AVATAR_FIELD))

    def _verify_avatar_token(self, employee_public, token):
        """Verify a `t` query param produced by `_avatar_url`."""
        return self._verify_image_token(employee_public, AVATAR_FIELD, token)

    def _safe_value(self, record, field_name):
        if not record or field_name not in record._fields:
            return None
        try:
            return record[field_name] or None
        except AccessError:
            return None

    def _selection_label(self, record, field_name):
        value = self._safe_value(record, field_name)
        if not value or field_name not in record._fields:
            return None
        try:
            selection = dict(record._fields[field_name]._description_selection(record.env))
        except Exception:
            return value
        return selection.get(value, value)

    def _own_private_employee(self, employee_public):
        """Private employee relation for optional Work-tab fields only, never Personal-tab data."""
        return employee_public.employee_id

    def _content_flags(self):
        """Whether each "Other Data" section (privacy policy, terms, FAQ) has content to show.
        sudo because mobile-only users have no ACL on these models; only booleans are returned."""
        return {
            "show_privacy_policy": bool(
                request.env["mobile.privacy.policy"].sudo().search_count(
                    [("is_published", "=", True)])),
            "show_terms_conditions": bool(
                request.env["mobile.terms.condition"].sudo().search_count(
                    [("is_published", "=", True)])),
            "show_faq": bool(
                request.env["mobile.faq"].sudo().search_count(
                    [("active", "=", True)])),
        }

    @main.http.route("/api/mobile/v1/profile", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def profile(self, **kwargs):
        employee_public, token, err = self._authenticate_profile()
        if err:
            return err

        try:
            return self._json(success=True, message="Profile fetched successfully",
                              data=self._profile_data(employee_public))
        except AccessError:
            # Defensive: a record rule can still hide a related record from this user.
            return self._json(success=False, code="profile_not_found",
                              message="Profile is not available for this user.",
                              status=404)

    def _profile_data(self, employee_public):
        private_employee = self._own_private_employee(employee_public)
        header = self._profile_header(employee_public)
        work = self._profile_work(employee_public, private_employee)
        personal = self._profile_personal(
            request.env['res.users']._mobile_own_private_profile_values())
        docs = self._profile_docs(employee_public)

        # Derive the flat selected_* fields from the list the app is sent so the two cannot disagree.
        companies = self._company_payload()
        selected = next(
            (company for company in companies if company["is_selected"]),
            next((company for company in companies if company["is_default"]), None),
        )

        data = {
            "id": employee_public.id,
            "name": employee_public.name,
            "job_title": employee_public.job_title or None,
            "email": employee_public.work_email or employee_public.email or None,
            "phone": employee_public.work_phone or None,
            "mobile": employee_public.mobile_phone or None,
            "department": employee_public.department_id.name or None,
            # The profile UI must show the company selected for this mobile session.
            "company": selected["name"] if selected else None,
            "work_location": _work_address(employee_public),
            "avatar_url": self._avatar_url(employee_public),
            "initials": _initials(employee_public.name),
            "header": header,
            "work": work,
            "personal": personal,
            "docs": docs,
            # Companies this user may switch between, for the profile-screen switcher.
            "companies": companies,
            # The active company, lifted out of the list so the app can render it directly.
            "selected_company_id": selected["id"] if selected else None,
            "selected_company_name": selected["name"] if selected else None,
        }
        # Top-level flags telling the app whether to show each "Other Data" link.
        data.update(self._content_flags())

        manager = employee_public.parent_id
        if manager:
            data["report_to"] = {
                "id": manager.id,
                "name": manager.name,
                "email": manager.work_email or manager.email or None,
                "job_title": manager.job_title or None,
                "avatar_url": self._avatar_url(manager),
                "can_connect": bool(manager.user_id),
            }
        else:
            data["report_to"] = None

        team = self._team_recordset(employee_public)
        data["team"] = [{
            "id": member.id,
            "name": member.name,
            "job_title": member.job_title or None,
            "avatar_url": self._avatar_url(member),
            "is_online": member.hr_presence_state in ONLINE_PRESENCE_STATES,
        } for member in team]

        return data

    def _profile_header(self, employee_public):
        return {
            "name": employee_public.name,
            "job_title": employee_public.job_title or None,
            "avatar_url": self._avatar_url(employee_public),
            "initials": _initials(employee_public.name),
        }

    def _profile_work(self, employee_public, private_employee):
        # Contract date and bank details live on `hr.employee`, which a plain mobile user cannot read.
        work_values = request.env["res.users"]._mobile_own_work_profile_values()
        bank_accounts = work_values.get("bank_accounts") or []
        primary_bank = bank_accounts[0] if bank_accounts else {}
        contract_start = work_values.get("contract_date_start")
        manager = employee_public.parent_id
        return {
            "email": employee_public.work_email or employee_public.email or None,
            "phone": employee_public.work_phone or employee_public.mobile_phone or None,
            "job_title": employee_public.job_title or None,
            "job_position": employee_public.job_id.name or None,
            "manager": {
                "id": manager.id,
                "name": manager.name,
                "email": manager.work_email or manager.email or None,
                "can_connect": bool(manager.user_id),
            } if manager else None,
            "contract_start_date": _iso_date(contract_start),
            "contract_start_date_display": _display_date(contract_start),
            # Kept for backwards compatibility: the app reads `bank` today.
            "bank": {
                "bank_name": primary_bank.get("bank_name"),
                "account_number": primary_bank.get("account_number"),
                "ifsc_code": primary_bank.get("ifsc_code"),
            },
            # Full list: the profile design shows more than one bank block.
            "bank_accounts": bank_accounts,
        }

    def _profile_personal(self, values):
        """Personal data from the connector's self-only allow-list for the authenticated employee."""
        birthday = values.get("birthday")
        private_address = _format_private_address(values)
        # Personal contact details come strictly from the employee's PRIVATE fields.
        return {
            "personal_email": values.get("private_email"),
            "phone": values.get("private_phone"),
            "gender": values.get("sex_label"),
            "date_of_birth": _iso_date(birthday),
            "date_of_birth_display": _display_date(birthday),
            "marital_status": values.get("marital_label"),
            "nationality": values.get("private_country_id"),
            "birth_place": values.get("place_of_birth"),
            "residential_address": private_address,
            # Standard Odoo stores one private/home address, not a separate permanent one.
            "permanent_address": private_address,
            "education_level": values.get("certificate_label"),
            "field_of_study": values.get("study_field"),
        }

    def _profile_docs(self, employee_public):
        """The employee's own documents: Binary document fields (``employee_documents``)
        and chatter attachments (``certificates``); fields with no file are omitted."""
        return {
            "employee_documents":
                self._employee_field_document_payloads(employee_public),
            "certificates": self._employee_document_payloads(employee_public),
        }

    def _employee_field_document_payloads(self, employee_public):
        """The Binary document fields, read via their `ir.attachment` rows for ids, size and mimetype.
        sudo: employees lack ACL on `ir.attachment`; constrained by `res_id` from the token."""
        registry = request.env["res.users"]._MOBILE_EMPLOYEE_DOCUMENT_FIELDS
        attachments = request.env["ir.attachment"].sudo().search([
            ("res_model", "=", "hr.employee"),
            ("res_id", "=", employee_public.id),
            ("res_field", "in", [field_name for _c, field_name in registry]),
            ("type", "=", "binary"),
        ])
        by_field = {a.res_field: a for a in attachments}

        # Labels come from Odoo's own field strings, so they stay translated and follow core relabelling.
        employee = request.env["hr.employee"].sudo().browse(employee_public.id)
        present = [f for _c, f in registry if f in employee._fields]
        labels = employee.fields_get(present, attributes=["string"]) if present else {}

        payloads = []
        for code, field_name in registry:
            attachment = by_field.get(field_name)
            if not attachment:
                continue  # nothing on file -- omitted, not a null placeholder
            label = labels.get(field_name, {}).get("string") or code
            payloads.append(
                self._employee_field_document_payload(attachment, code, label))
        return payloads

    def _employee_field_document_payload(self, attachment, code, label):
        """One Binary-field document as a `certificates` resource, delegating to `_document_payload`.
        Only ``code``, ``name`` (translated label) and ``filename`` (with extension) are overridden."""
        payload = self._document_payload(attachment)
        payload["code"] = code
        payload["name"] = label
        payload["filename"] = self._document_filename(
            code, attachment.mimetype or "application/octet-stream")
        return payload

    @staticmethod
    def _document_filename(code, mimetype):
        """``<code>.<ext>``, e.g. ``driving_license.jpg``; the code is a stable, filename-safe slug.
        JPEG maps to `.jpg` and an unknown type gets no extension."""
        override = {"image/jpeg": ".jpg", "application/octet-stream": ""}
        extension = override.get(mimetype)
        if extension is None:
            extension = mimetypes.guess_extension(mimetype) or ""
        return "%s%s" % (code, extension)

    @main.http.route("/api/mobile/v1/profile/employee-documents/<code>",
                     type="http", auth="none", methods=["GET"], csrf=False)
    def profile_employee_document(self, code, **kwargs):
        """Download one of the caller's own Binary document fields by registry code.
        `code` goes through the registry, never used as a field name; bad values get a JSON 404."""
        employee_public, token, err = self._authenticate_profile()
        if err:
            return err

        document = request.env["res.users"]._mobile_own_employee_document(code)
        if not document:
            # One answer for "no such code" and "nothing on file" so the two cannot be told apart.
            return self._json(success=False, code="document_not_found",
                              message="No document is on file.", status=404)

        return self._json(success=True,
                          message="Document downloaded successfully",
                          data=self._binary_document_download(document))

    @main.http.route("/api/mobile/v1/profile/id-card", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def profile_id_card(self, **kwargs):
        """Deprecated: use `/profile/employee-documents/id_card`; kept for older app builds."""
        employee_public, token, err = self._authenticate_profile()
        if err:
            return err

        id_card = request.env["res.users"]._mobile_own_id_card()
        if not id_card:
            return self._json(success=False, code="id_card_not_found",
                              message="No ID card is on file.", status=404)

        payload = self._binary_document_download(id_card)
        # Filename kept stable for older app builds.
        extension = (id_card["mimetype"].rsplit("/", 1)[-1] or "bin").lower()
        payload["filename"] = "company-id.%s" % extension
        return self._json(success=True, message="ID card downloaded successfully",
                          data=payload)

    def _binary_document_download(self, document):
        """Base64 download payload for a Binary-field document, with a synthesised filename."""
        mimetype = document["mimetype"] or "application/octet-stream"
        extension = (mimetype.rsplit("/", 1)[-1] or "bin").lower()
        return {
            "filename": "%s.%s" % (document["code"], extension),
            "content_type": mimetype,
            "base64": base64.b64encode(document["content"]).decode(),
        }

    def _employee_document_payloads(self, employee_public):
        # Attachments are not reliably readable to non-HR employees via normal ACLs, hence sudo + domain.
        attachments = request.env["ir.attachment"].sudo().search([
            ("res_model", "=", "hr.employee"),
            ("res_id", "=", employee_public.id),
            # Explicit, matching _own_document.
            ("res_field", "=", False),
            ("type", "=", "binary"),
        ], order="id desc", limit=50)
        return [self._document_payload(attachment) for attachment in attachments]

    def _document_payload(self, attachment):
        return {
            "id": attachment.id,
            "name": attachment.name,
            "filename": attachment.name,
            "mimetype": attachment.mimetype or "application/octet-stream",
            "file_size": attachment.file_size,
            # Same mobile consumption style as the payslip download.
            "download": {
                "endpoint": "/api/mobile/v1/profile/documents/%s/download" % attachment.id,
                "method": "GET",
                "requires_auth": True,
                "response": "base64",
            },
            # Coarse bucket, same vocabulary as the log-note attachment payload.
            "kind": self._attachment_kind(attachment),
            # Lightweight renderable version for the Docs card (PDF page 1, image, or text).
            "preview": {
                "endpoint": "/api/mobile/v1/profile/documents/%s/preview" % attachment.id,
                "method": "GET",
                "requires_auth": True,
                "preview_as": self._previewable_as(attachment),
            },
        }

    @main.http.route("/api/mobile/v1/profile/avatar", type="http", auth="none",
                     methods=["GET"], csrf=False)
    def profile_avatar(self, **kwargs):
        employee_public, token, err = self._authenticate_profile()
        if err:
            return err
        return self._avatar_stream(employee_public, **kwargs)

    @main.http.route("/api/mobile/v1/employees/<employee_id>/avatar",
                     type="http", auth="none", methods=["GET"], csrf=False)
    def employee_avatar(self, employee_id, **kwargs):
        """Avatar via a signed `?t=` link token or a Bearer token plus `_can_view_employee`.
        `<employee_id>` is not `<int:>` so a malformed id gets a JSON 404, not an HTML page."""
        try:
            employee_id = int(employee_id)
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_employee_id",
                              message="employee_id must be an integer.",
                              status=400)

        link_token = request.httprequest.args.get("t")
        if link_token:
            # No Bearer token on this path: access is granted by the signed avatar token.
            target = request.env["hr.employee.public"].browse(employee_id)
            if not target.exists() or not self._verify_avatar_token(target, link_token):
                return self._json(success=False, code="avatar_token_invalid",
                                  message="This avatar link is invalid or has expired.",
                                  status=403)
            # This request never authenticates a user, so drop to the public user before streaming.
            public_uid = request.env.ref("base.public_user").id
            target_pub = target.with_env(request.env(user=public_uid))
            return self._avatar_stream(target_pub.sudo(), **kwargs)

        employee_public, token, err = self._authenticate_profile()
        if err:
            return err
        if not self._can_view_employee(employee_public, employee_id):
            return self._json(success=False, code="employee_not_visible",
                              message="This profile is not available to you.",
                              status=403)
        target = request.env["hr.employee.public"].browse(employee_id)
        if not target.exists():
            return self._json(success=False, code="employee_not_found",
                              message="Employee not found.", status=404)
        return self._avatar_stream(target, **kwargs)

    @main.http.route("/api/mobile/v1/profile/documents/<attachment_id>/download",
                     type="http", auth="none", methods=["GET"], csrf=False)
    def profile_document_download(self, attachment_id, **kwargs):
        try:
            attachment_id = int(attachment_id)
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_document_id",
                              message="document_id must be an integer.",
                              status=400)

        employee_public, token, err = self._authenticate_profile()
        if err:
            return err

        attachment = self._own_document(attachment_id, employee_public)
        if not attachment:
            return self._json(success=False, code="document_not_found",
                              message="Document not found.", status=404)

        try:
            content = base64.b64decode(attachment.datas or b"")
        except Exception:
            return self._json(success=False, code="document_download_failed",
                              message="Unable to download this document.",
                              status=500)

        return self._json(success=True, message="Document downloaded successfully",
                          data={
                              "filename": self._download_filename(attachment),
                              "content_type": attachment.mimetype or
                                              "application/octet-stream",
                              "base64": base64.b64encode(content).decode("ascii"),
                          })

    def _download_filename(self, attachment):
        """The name to save this attachment as; field-backed documents use `_document_filename`."""
        if not attachment.res_field:
            return attachment.name
        code = dict(
            (field_name, code) for code, field_name in
            request.env["res.users"]._MOBILE_EMPLOYEE_DOCUMENT_FIELDS
        ).get(attachment.res_field)
        if not code:
            return attachment.name
        return self._document_filename(
            code, attachment.mimetype or "application/octet-stream")

    @main.http.route("/api/mobile/v1/profile/documents/<attachment_id>/preview",
                     type="http", auth="none", methods=["GET"], csrf=False)
    def profile_document_preview(self, attachment_id, **kwargs):
        """Small preview for the Docs card; ``kind`` is pdf_page, image, text or none (still 200).
        Odoo's thumbnail is browser-generated, so it is built here; ownership via ``_own_document``."""
        try:
            attachment_id = int(attachment_id)
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_document_id",
                              message="document_id must be an integer.",
                              status=400)

        employee_public, token, err = self._authenticate_profile()
        if err:
            return err

        attachment = self._own_document(attachment_id, employee_public)
        if not attachment:
            return self._json(success=False, code="document_not_found",
                              message="Document not found.", status=404)

        previewable_as = self._previewable_as(attachment)
        data = {
            "filename": attachment.name,
            # Coarse bucket, shared with the log-note attachment payload.
            "kind": self._attachment_kind(attachment),
            # What this response actually carries, or None when the file has no preview.
            "preview_as": previewable_as,
            "content_type": attachment.mimetype or "application/octet-stream",
            "base64": None,
            "text": None,
        }

        try:
            if previewable_as == "pdf_page":
                page_stream = _extract_pdf_page(attachment, 0)
                if not page_stream:
                    return self._preview_unavailable()
                data["content_type"] = "application/pdf"
                data["page"] = 1
                data["base64"] = base64.b64encode(
                    page_stream.getvalue()).decode("ascii")

            elif previewable_as == "image":
                # Downscaled copy, not the original: a phone photo would be megabytes over the wire.
                resized = _resize_image(attachment.raw or b"")
                if not resized:
                    return self._preview_unavailable()
                data["base64"] = base64.b64encode(resized).decode("ascii")

            elif previewable_as == "text":
                raw = attachment.raw or b""
                data["text"] = raw[:TEXT_PREVIEW_MAX_BYTES].decode(
                    "utf-8", errors="replace")
                data["truncated"] = len(raw) > TEXT_PREVIEW_MAX_BYTES

            # previewable_as is None: a success carrying no content.
        except Exception:
            _logger.exception(
                "Preview generation failed for attachment %s (kind=%s, "
                "preview_as=%s, mimetype=%s).",
                attachment.id, data["kind"], previewable_as, attachment.mimetype)
            return self._preview_unavailable()

        return self._json(success=True, message="Document preview generated",
                          data=data)

    def _preview_unavailable(self):
        """The file *should* have been previewable but could not be read."""
        return self._json(success=False, code="preview_unavailable",
                          message="No preview available for this document.",
                          status=422)

    def _company_payload(self):
        """Companies the caller may act as; `is_default` is home, `is_selected` this session's scope.
        sudo on `company_ids` only, since `res.company` has no read ACL for a plain employee."""
        user = request.env.user
        selected_ids = set(self._get_company_context(user.id))
        default_id = user.sudo().company_id.id
        # Only companies that actually employ this user; offering any other would dead-end.
        switchable = request.env["res.company"].sudo().browse(
            self._employment_company_ids(user))
        return [{
            "id": company.id,
            "name": company.name,
            "is_default": company.id == default_id,
            "is_selected": company.id in selected_ids,
        } for company in switchable.sorted("name")]

    def _own_document(self, attachment_id, employee_public):
        """The caller's own document by id, or empty; the single gate for download and preview.
        sudo is bounded by token res_id and an explicit res_field allow-list (Odoo omits it with id)."""
        return request.env["ir.attachment"].sudo().search([
            ("id", "=", attachment_id),
            ("res_model", "=", "hr.employee"),
            ("res_id", "=", employee_public.id),
            ("res_field", "in", [False] + self._employee_document_field_names()),
            ("type", "=", "binary"),
        ], limit=1)

    def _employee_document_field_names(self):
        """The `hr.employee` Binary fields published as documents, from the connector registry."""
        return [field_name for _code, field_name in
                request.env["res.users"]._MOBILE_EMPLOYEE_DOCUMENT_FIELDS]

    @staticmethod
    def _attachment_kind(attachment):
        """Coarse bucket (image/video/audio/pdf/file), falling back on the filename for octet-stream."""
        mimetype = (attachment.mimetype or "").lower()
        for prefix, kind in ATTACHMENT_KIND_BY_PREFIX.items():
            if mimetype.startswith(prefix):
                return kind
        if "pdf" in mimetype:
            return ATTACHMENT_KIND_PDF

        name = (attachment.name or "").lower()
        if name.endswith(".pdf"):
            return ATTACHMENT_KIND_PDF
        if name.endswith((".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp")):
            return "image"
        return ATTACHMENT_KIND_FILE

    def _is_pdf_attachment(self, attachment):
        return self._attachment_kind(attachment) == ATTACHMENT_KIND_PDF

    def _is_image_attachment(self, attachment):
        if self._attachment_kind(attachment) != "image":
            return False
        # SVG is an image but not raster: image_process returns it untouched.
        return "svg" not in (attachment.mimetype or "").lower()

    @staticmethod
    def _is_text_attachment(attachment):
        mimetype = (attachment.mimetype or "").lower()
        if mimetype.startswith(TEXT_PREVIEW_MIMETYPES):
            return True
        return (attachment.name or "").lower().endswith(TEXT_PREVIEW_EXTENSIONS)

    def _previewable_as(self, attachment):
        """What this endpoint can actually render as a preview, or None."""
        if self._is_pdf_attachment(attachment):
            return "pdf_page"
        if self._is_image_attachment(attachment):
            return "image"
        if self._is_text_attachment(attachment):
            return "text"
        return None

    def _avatar_stream(self, employee_public, **kwargs):
        """Stream an avatar via `main._image_stream_response`, which clamps width and height.
        The clamp matters: the `?t=` path is reachable unauthenticated."""
        return self._image_stream_response(
            employee_public, AVATAR_FIELD, query=kwargs,
            not_found_code="avatar_not_found",
            not_found_message="No avatar is available.")
