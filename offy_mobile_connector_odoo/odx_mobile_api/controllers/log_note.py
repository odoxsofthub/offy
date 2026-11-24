"""Log-note (chatter) endpoints: mention suggestions, messages (list/create/edit/delete) and attachments.
Delegates mention ranking and the thread domain to `mail` and replaces only the `Store` serialisation layer.
"""

import json
import logging
import re

import pytz
from lxml import html
from lxml.etree import ParserError
from markupsafe import Markup, escape

from odoo.exceptions import AccessError, UserError
from odoo.http import request
from odoo.tools.mail import html2plaintext, is_html_empty

from . import main
from .expense import expense_payload, expense_payment_payload
from .home import _iso_utc
from .main import API_KEY_SCOPE
from .uploads import validate_upload

_logger = logging.getLogger(__name__)

THREAD_SOURCES = {
    "expense": ("hr.expense", "expense"),
    "timeoff": ("hr.leave", "time_off"),
    "payslip": ("hr.payslip", "payslip"),
    "calendar": ("calendar.event", "calendar"),
    # Keep the mobile-facing typo as an alias so existing clients that send it keep working.
    "calender": ("calendar.event", "calendar"),
}

# Match the source-specific not-found convention used by the other endpoints.
THREAD_NOT_FOUND = {
    "expense": ("expense_not_found", "Expense not found."),
    "timeoff": ("timeoff_not_found", "Time off request not found."),
    "payslip": ("payslip_not_found", "Payslip not found."),
    "calendar": ("calendar_event_not_found", "Calendar event not found."),
    "calender": ("calendar_event_not_found", "Calendar event not found."),
}

MSG_TYPE_NOTE = "note"          # a person typed it, internal log note
MSG_TYPE_COMMENT = "comment"    # a person typed it, sent to followers
MSG_TYPE_SYSTEM = "system"      # Odoo generated it, has a body
MSG_TYPE_ACTIVITY = "activity"  # a scheduled activity was logged as done
# There is deliberately no "tracking" type.

# Odoo pretty-prints its HTML, so whitespace-only text nodes between blocks are noise.
_WHITESPACE_RUN = re.compile(r"\s+")
# Spaces stranded either side of a line break we inserted ourselves.
_SPACE_AROUND_NEWLINE = re.compile(r" *\n *")
# Adjacent text nodes each collapse to a single space independently, so runs can stack up.
_MULTI_SPACE = re.compile(r" {2,}")
# Three or more breaks in a row read as an accidental gap, never as intent.
_EXCESS_NEWLINES = re.compile(r"\n{3,}")
# Time Off approve/refuse messages print `date_from` with a time (UTC on refusal);
# the mobile log keeps only the date.
_LEAVE_DATETIME = re.compile(r"\b(\d{4}-\d{2}-\d{2}) \d{2}:\d{2}:\d{2}\b")

# An "empty" body as Odoo actually stores it.
EMPTY_BODY_VALUES = [
    "<p><br></p>",
    "<p><br/></p>",
    "<p></p>",
    "<div><br></div>",
    '<div class="o-paragraph"><br></div>',
    '<div class="o-paragraph"><br/></div>',
    # A message whose text was edited away entirely.
    '<span class="o-mail-Message-edited"></span>',
]

ALIGN_OWN = "own"
ALIGN_OTHER = "other"
ALIGN_SYSTEM = "system"

# Coarse buckets so the app can pick a renderer without parsing mimetypes.
ATTACHMENT_KIND_BY_PREFIX = {
    "image/": "image",
    "video/": "video",
    "audio/": "audio",
}
ATTACHMENT_KIND_PDF = "pdf"
ATTACHMENT_KIND_FILE = "file"

# `ir.attachment.raw` is the binary streamed by the authenticated download endpoint.
ATTACHMENT_FIELD = "raw"
# Square box for the inline image preview in a chat bubble.
ATTACHMENT_THUMBNAIL_PX = 512

DEFAULT_MESSAGE_LIMIT = 30
MAX_MESSAGE_LIMIT = 50
MAX_LOG_NOTE_BODY_LENGTH = 10_000
MAX_LOG_NOTE_ATTACHMENTS = 5
MAX_LOG_NOTE_ATTACHMENT_SIZE = 10 * 1024 * 1024  # 10 MB per file
LOG_NOTE_ATTACHMENT_FIELDS = ("attachment", "attachments", "attachments[]", "file")

# Keep log-note access consistent with the payslip list/detail APIs: only issued payslips.
VISIBLE_PAYSLIP_STATES = ("validated", "paid")

# `res.partner.avatar_128` is the size Odoo's own chatter mention dropdown uses.
MENTION_AVATAR_FIELD = "avatar_128"

# Odoo's web dropdown defaults to 8 because it renders under a text cursor.
DEFAULT_MENTION_LIMIT = 20
# Same ceiling every other list endpoint in this module uses.
MAX_MENTION_LIMIT = 50


class MobileApiLogNote(main.MobileApiAuth):
    """Log-note composer support: @mention suggestions and their avatars."""

    def _thread_not_found(self, source):
        code, message = THREAD_NOT_FOUND.get(
            source, ("record_not_found", "Record not found."))
        return self._json(success=False, code=code, message=message, status=404)

    def _authenticate_log_note(self):
        """Shared auth, eligibility and company scope; returns (user, error_response).
        Does not require an employee: a user without `hr.employee` can still write a log note.
        """
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
        return user, None

    def _resolve_thread(self, user, source, record_id, write=False):
        """Resolve (source, record_id) to a readable thread via allowlist, feature gate and an ORM read as the user (no sudo).
        Every failure is the same 404 so the endpoint cannot be used to enumerate record ids.
        """
        if source not in THREAD_SOURCES:
            return None, self._json(
                success=False, code="invalid_source",
                message="Unknown source. Expected one of: %s."
                        % ", ".join(sorted(THREAD_SOURCES)),
                status=400)

        model_name, feature_code = THREAD_SOURCES[source]

        try:
            record_id = int(record_id)
        except (TypeError, ValueError):
            return None, self._json(success=False, code="invalid_record_id",
                                    message="id must be an integer.",
                                    status=400)

        if not self._mobile_feature_allowed(user, feature_code):
            return None, self._json(
                success=False, code="%s_access_denied" % feature_code,
                message="You are not allowed to access this feature.",
                status=403)

        try:
            # Use a normal search instead of `_get_thread_with_access()`.
            if source == "payslip":
                # hr.payslip has no normal employee read ACL, even for the payslip owner.
                employee = request.env["hr.employee"].sudo().search(
                    [("user_id", "=", user.id),
                     # Company-scoped: without this, limit=1 picks the lowest-id employee across companies.
                     ("company_id", "in", self._allowed_company_ids())],
                    limit=1)
                thread = request.env[model_name].sudo().search([
                    ("id", "=", record_id),
                    ("employee_id", "=", employee.id),
                    ("state", "in", VISIBLE_PAYSLIP_STATES),
                    # sudo() drops the company record rules; re-apply them, matching the payslip endpoints.
                    ("employee_id.company_id", "in", self._allowed_company_ids()),
                ], limit=1)
            else:
                thread = request.env[model_name].search(
                    [("id", "=", record_id)], limit=1)
            if thread and write:
                if source == "expense":
                    # Once an expense is approved, Odoo no longer grants its owner read access.
                    employee = request.env["hr.employee"].sudo().search(
                        [("user_id", "=", user.id),
                         # Company-scoped: the ownership test below compares against this one employee.
                         ("company_id", "in", self._allowed_company_ids())],
                        limit=1)
                    if employee and thread.employee_id.id == employee.id:
                        thread = thread.sudo()
                    else:
                        thread = request.env[model_name]
                    # The ownership check above is the whole exception to the normal access path.
                    if thread:
                        return thread, None
                # `mail.thread` lets models define the precise document permission needed to post.
                post_access = thread._mail_get_operation_for_mail_message_operation(
                    "create").get(thread)
                if not post_access or not thread.has_access(post_access):
                    thread = request.env[model_name]
        except AccessError:
            thread = request.env[model_name]
        if not thread:
            return None, self._thread_not_found(source)
        return thread, None

    def _create_log_note_payload(self, kwargs):
        """Merge JSON and multipart fields for the create endpoint."""
        payload = self._payload()
        payload.update(kwargs or {})
        payload.update(request.httprequest.form.to_dict(flat=True))
        return payload

    def _log_note_files(self):
        files = []
        for field_name in LOG_NOTE_ATTACHMENT_FIELDS:
            files.extend(request.httprequest.files.getlist(field_name))
        return files

    def _log_note_is_empty(self, body, mention_ids):
        """True when *body* would render as nothing (e.g. `<p>   </p>`); mentions count as content.
        Prevents saving invisible empty notes and edits that leave only Odoo's "edited" marker.
        """
        if mention_ids:
            return False
        return not body or is_html_empty(body)

    def _log_note_attachments(self):
        """Read and validate uploaded files into `message_post(attachments=...)` triples, or return an error.
        Shared by create and edit so the count, size and type rules cannot drift.
        """
        files = self._log_note_files()
        if len(files) > MAX_LOG_NOTE_ATTACHMENTS:
            return None, self._json(
                success=False, code="too_many_attachments",
                message="A maximum of %d attachments is allowed."
                        % MAX_LOG_NOTE_ATTACHMENTS, status=400)
        attachments = []
        for file_storage in files:
            filename = (file_storage.filename or "").strip()
            if not filename:
                return None, self._json(
                    success=False, code="invalid_attachment",
                    message="Each attachment must include a filename.", status=400)
            content = file_storage.read()
            if not content:
                return None, self._json(
                    success=False, code="invalid_attachment",
                    message="Attachments must not be empty.", status=400)
            if len(content) > MAX_LOG_NOTE_ATTACHMENT_SIZE:
                return None, self._json(
                    success=False, code="invalid_attachment",
                    message="Each attachment must be at most %d MB."
                            % (MAX_LOG_NOTE_ATTACHMENT_SIZE // (1024 * 1024)),
                    status=400)
            # The declared Content-Type is discarded: it is client-written and an SVG under an image type is XSS.
            mimetype, problem = validate_upload(filename, content)
            if problem:
                return None, self._json(
                    success=False, code="invalid_attachment",
                    message=problem, status=400)
            attachments.append((filename, content, {"mimetype": mimetype}))
        return attachments, None

    def _log_note_body(self, raw_parts):
        """Validate body parts and build Odoo's native mention anchors from partner ids.
        Client-supplied mention labels are discarded so a mention's visible text cannot be spoofed.
        """
        if isinstance(raw_parts, str):
            try:
                raw_parts = json.loads(raw_parts)
            except (TypeError, ValueError):
                return None, None, "body_parts must be a valid JSON array."
        if not isinstance(raw_parts, list):
            return None, None, "body_parts must be an array."

        mention_ids = []
        text_length = 0
        for part in raw_parts:
            if not isinstance(part, dict) or part.get("type") not in ("text", "mention"):
                return None, None, "Each body part must have type text or mention."
            if part["type"] == "text":
                if not isinstance(part.get("text"), str):
                    return None, None, "A text body part must include text."
                text_length += len(part["text"])
            else:
                try:
                    mention_ids.append(int(part.get("partner_id")))
                except (TypeError, ValueError):
                    return None, None, "A mention body part must include partner_id."
                # Optional, and never used to render.
                for label_key in ("name", "text"):
                    label = part.get(label_key)
                    if label is not None and not isinstance(label, str):
                        return None, None, (
                            "A mention body part's %s must be a string."
                            % label_key)
        if text_length > MAX_LOG_NOTE_BODY_LENGTH:
            return None, None, "The log note text is too long."

        partners = request.env["res.partner"].search([
            ("id", "in", list(set(mention_ids))), ("active", "=", True),
        ]) if mention_ids else request.env["res.partner"]
        partners_by_id = {partner.id: partner for partner in partners}
        if any(partner_id not in partners_by_id for partner_id in mention_ids):
            return None, None, "One or more mentioned users are unavailable."

        html_parts = []
        for part in raw_parts:
            if part["type"] == "text":
                # Preserve line breaks while escaping every client-provided character.
                html_parts.append(escape(part["text"]).replace("\n", Markup("<br/>")))
                continue
            partner = partners_by_id[int(part["partner_id"])]
            html_parts.append(Markup(
                '<a href="#" class="o_mail_redirect" '
                'data-oe-model="res.partner" data-oe-id="%s">@%s</a>'
            ) % (partner.id, escape(partner.name or "")))

        if not any(str(part) for part in html_parts):
            return Markup(""), mention_ids, None
        return Markup("<p>%s</p>") % Markup("").join(html_parts), mention_ids, None

    def _message_type(self, message):
        """Classify a `mail.message` for rendering; checks run most-specific first."""
        if message.mail_activity_type_id:
            return MSG_TYPE_ACTIVITY
        if message.message_type == "comment":
            note_subtype = request.env.ref("mail.mt_note", raise_if_not_found=False)
            if note_subtype and message.subtype_id == note_subtype:
                return MSG_TYPE_NOTE
            return MSG_TYPE_COMMENT
        return MSG_TYPE_SYSTEM

    def _message_align(self, message, own_partner):
        """Which side of the thread the bubble belongs on, based on author only (not `type`).
        Odoo authors generated messages as the acting user; only authorless messages are centred.
        """
        author = message.author_id
        if not author:
            return ALIGN_SYSTEM
        return ALIGN_OWN if author == own_partner else ALIGN_OTHER

    def _has_body(self, message):
        """Whether the body holds readable content; Odoo often stores empty bodies as `<p><br></p>`."""
        return bool((html2plaintext(message.body or "") or "").strip())

    def _log_note_attachment_kind(self, mimetype):
        """Classify a chatter attachment from its MIME type.
        Named log-note-specific to avoid colliding with Profile's `_attachment_kind` through controller inheritance.
        """
        mimetype = (mimetype or "").lower()
        for prefix, kind in ATTACHMENT_KIND_BY_PREFIX.items():
            if mimetype.startswith(prefix):
                return kind
        if mimetype == "application/pdf":
            return ATTACHMENT_KIND_PDF
        return ATTACHMENT_KIND_FILE

    def _attachment_url(self, attachment, **params):
        """Bearer-protected URL for one attachment; never put a bearer equivalent in the query string."""
        query = "".join("&%s=%s" % (key, value) for key, value in params.items())
        separator = "?" if query else ""
        return "%s/api/mobile/v1/log-note/attachments/%s%s%s" % (
            self._api_base_url(), attachment.id, separator, query.lstrip("&"))

    def _attachment_payload(self, attachment):
        kind = self._log_note_attachment_kind(attachment.mimetype)
        payload = {
            "id": attachment.id,
            "name": attachment.name or "",
            "mimetype": attachment.mimetype or "application/octet-stream",
            "kind": kind,
            "size": attachment.file_size or 0,
            "url": self._attachment_url(attachment),
            "download_requires_auth": True,
            "thumbnail_url": None,
        }
        if kind == "image":
            # Same signed route, resized server-side, so a thread of photos does not download full images.
            payload["thumbnail_url"] = self._attachment_url(
                attachment, width=ATTACHMENT_THUMBNAIL_PX,
                height=ATTACHMENT_THUMBNAIL_PX)
        return payload

    def _record_payload(self, thread):
        """Describe the thread's record: `model`, `id` and `name`, plus the full expense payload and attachments for expenses.
        Reuses `expense_payload` so an expense looks the same here, in the list and in the summary.
        """
        payload = {
            "model": thread._name,
            "id": thread.id,
            "name": thread.display_name or "",
        }
        if thread._name != "hr.expense":
            return payload

        # Currency follows the same source as the expense endpoints, so the amount matches.
        currency = request.env.company.currency_id
        try:
            payload.update(expense_payload(thread, currency))
            # Reimbursement progress.
            payload.update(expense_payment_payload(thread.sudo()))
        except AccessError:
            # The thread itself was already access-checked; a field-level denial only drops the expense card.
            _logger.info(
                "Expense payload unavailable for record %s in log-note.",
                thread.id)
            return payload

        # `name` is the generic key every source returns; `expense_payload` calls it `title`.
        payload["name"] = payload.get("title") or payload["name"]

        # Files attached when the expense was created, e.g. receipts.
        payload["attachments"] = [
            self._attachment_payload(attachment)
            for attachment in self._record_own_attachments(thread.sudo())
        ]
        return payload

    def _attachment_thread_source(self, attachment):
        """Return the mobile source and record id owning an attachment, unwrapping `mail.message` links.
        No global fallback lookup: an attachment id is not authorisation.
        """
        model_name = attachment.res_model
        record_id = attachment.res_id
        if model_name == "mail.message" and record_id:
            message = request.env["mail.message"].sudo().browse(record_id)
            if not message.exists():
                return None, None
            model_name, record_id = message.model, message.res_id

        if not model_name or not record_id:
            return None, None
        source = self._source_for_model(model_name)
        return (source, record_id) if source else (None, None)

    def _note_can_delete(self, message, own_partner):
        """Gates 2 and 3 of `_resolve_own_note` for one message, so `is_deletable` matches what DELETE enforces."""
        return bool(message.author_id == own_partner
                    and message.message_type == "comment")

    def _note_can_edit(self, message, own_partner):
        """As `_note_can_delete`, but also refuses messages with tracking values (Odoo's edit rule).
        sudo() only reads `tracking_value_ids`, which is restricted to base.group_system.
        """
        if not self._note_can_delete(message, own_partner):
            return False
        return not message.sudo().tracking_value_ids

    def _resolve_own_note(self, user, raw_id, operation="delete"):
        """Resolve *raw_id* to a note this caller may edit or delete: thread reachable, caller is author, type is comment.
        These gates authorise the later sudo(), which is needed because core unlink requires write access on the document.
        """
        try:
            message_id = int(raw_id)
        except (TypeError, ValueError):
            return None, None, None, self._json(
                success=False, code="invalid_message_id",
                message="message_id is required and must be an integer.",
                status=400)

        not_found = self._json(success=False, code="message_not_found",
                               message="Message not found.", status=404)

        # sudo() to READ the routing fields only.
        message = request.env["mail.message"].sudo().browse(message_id)
        if not message.exists():
            return None, None, None, not_found

        source = self._source_for_model(message.model)
        if not source or not message.res_id:
            return None, None, None, not_found

        thread, err = self._resolve_thread(user, source, message.res_id, write=True)
        if err:
            return None, None, None, not_found

        if message.author_id != user.partner_id:
            return None, None, None, self._json(
                success=False, code="message_not_author",
                message="You can only change your own messages.", status=403)

        # `_note_can_delete` / `_note_can_edit` are the SAME expressions the list uses.
        allowed = (self._note_can_edit if operation == "edit"
                   else self._note_can_delete)(message, user.partner_id)
        if not allowed:
            # Distinguish the two reasons, since only one is actionable.
            if message.message_type != "comment":
                detail = "Only a log note you wrote can be changed."
            else:
                detail = ("This note recorded a field change and can no "
                          "longer be edited. You can still delete it.")
            return None, None, None, self._json(
                success=False, code="message_not_deletable",
                message=detail, status=403)

        return message, thread, source, None

    def _source_for_model(self, model_name):
        """Reverse `THREAD_SOURCES`; None means the model is not addressable from mobile (no global fallback)."""
        for source, (thread_model, _feature) in THREAD_SOURCES.items():
            # Prefer the correctly-spelled calendar source when matching the shared model.
            if thread_model == model_name and source != "calender":
                return source
        return None

    def _author_payload(self, message):
        author = message.author_id
        if not author:
            # Inbound mail with no matching partner still has a From header; show it instead of a blank.
            return {"id": None, "name": message.email_from or "System",
                    "image_url": None, "user_id": None}
        try:
            internal_user = author.user_ids.filtered(lambda u: not u.share)[:1]
        except AccessError:
            internal_user = None
        return {
            "id": author.id,
            "name": author.name or "",
            "image_url": self._mention_avatar_url(author),
            "user_id": internal_user.id if internal_user else None,
        }

    def _message_body_parts(self, message):
        """Return plain text and @mentions (`data-oe-model="res.partner"` anchors) as render-ready parts.
        Ordinary partner links are only treated as mentions when their label starts with `@`.
        """
        parts = []

        def add_text(value, raw=False):
            """Append body text, collapsing insignificant HTML whitespace (`raw=True` keeps inserted line breaks).
            Whitespace-only nodes become one space so adjacent inline elements stay separated.
            """
            if not value:
                return
            if not raw:
                value = _WHITESPACE_RUN.sub(" ", value)
            if not value:
                return
            if parts and parts[-1]["type"] == "text":
                parts[-1]["text"] += value
            else:
                parts.append({"type": "text", "text": value})

        def add_mention(element):
            label = (element.text_content() or "").strip()
            try:
                partner_id = int(element.get("data-oe-id"))
            except (TypeError, ValueError):
                return False
            if not label.startswith("@"):
                return False
            parts.append({
                "type": "mention",
                "partner_id": partner_id,
                "name": label[1:].strip(),
                "text": label,
            })
            return True

        def is_invisible(element):
            """Whether this subtree is never shown, e.g. display:none email preheaders and `<style>`/`<script>`."""
            if element.tag in ("style", "script"):
                return True
            style = (element.get("style") or "").replace(" ", "").lower()
            return "display:none" in style

        def walk(element):
            add_text(element.text)
            for child in element:
                is_partner_link = (
                    child.tag == "a"
                    and child.get("data-oe-model") == "res.partner"
                )
                if is_invisible(child):
                    # Skip the subtree, but not `tail` -- that text sits after the element.
                    pass
                elif is_partner_link and add_mention(child):
                    # The anchor's entire visible content belongs to the mention; do not emit it as text.
                    pass
                elif child.tag == "br":
                    add_text("\n", raw=True)
                else:
                    walk(child)
                add_text(child.tail)
            if element.tag in ("p", "div", "li"):
                add_text("\n", raw=True)

        try:
            root = html.fragment_fromstring(
                message.body or "", create_parent="div")
        except (TypeError, ValueError, ParserError):
            return [{"type": "text", "text":
                     (html2plaintext(message.body or "") or "").strip()}]
        walk(root)

        # Tidy the assembled text.
        for index, part in enumerate(parts):
            if part["type"] != "text":
                continue
            text = _MULTI_SPACE.sub(" ", part["text"])
            text = _SPACE_AROUND_NEWLINE.sub("\n", text)
            text = _EXCESS_NEWLINES.sub("\n\n", text)
            if index == 0:
                text = text.lstrip()
            parts[index]["text"] = text
        if parts and parts[-1]["type"] == "text":
            parts[-1]["text"] = parts[-1]["text"].rstrip()
        # Drop any text part the tidy-up emptied, keeping mentions untouched.
        parts = [part for part in parts
                 if part["type"] != "text" or part["text"]]
        return parts

    def _message_payload(self, message, own_partner, tz, thread_writable=True):
        """One message as the mobile chat renders it.
        `thread_writable` gates the edit/delete flags, since PATCH/DELETE resolve the thread for writing.
        """
        local_dt = message.date and pytz.utc.localize(
            message.date).astimezone(tz)
        body_parts = self._message_body_parts(message)
        if message.model == "hr.leave" and message.message_type == "notification":
            # Only Odoo's own messages; an employee's typed note is never rewritten.
            for part in body_parts:
                if part["type"] == "text":
                    part["text"] = _LEAVE_DATETIME.sub(r"\1", part["text"])
        return {
            "id": message.id,
            # Whether THIS caller may edit / delete THIS message, decided per message.
            "is_editable": thread_writable and self._note_can_edit(
                message, own_partner),
            "is_deletable": thread_writable and self._note_can_delete(
                message, own_partner),
            "type": self._message_type(message),
            "align": self._message_align(message, own_partner),
            "author": self._author_payload(message),
            "subject": message.subject or None,
            # The body is delivered ONLY as `body_parts`, an ordered list of text and mention parts.
            "body_parts": body_parts,
            "has_body": self._has_body(message),
            # UTC instant, plus the pre-resolved local pieces.
            "date": _iso_utc(message.date) if message.date else None,
            "day_key": local_dt.strftime("%Y-%m-%d") if local_dt else None,
            "time_display": local_dt.strftime("%I:%M %p").lstrip("0") if local_dt else None,
            # Compact, de-duplicated mention list alongside the positional body_parts.
            "mentions": [
                {"id": part["partner_id"], "name": part["name"]}
                for index, part in enumerate(body_parts)
                if part["type"] == "mention"
                and not any(
                    earlier["type"] == "mention"
                    and earlier["partner_id"] == part["partner_id"]
                    for earlier in body_parts[:index]
                )
            ],
            "attachments": [self._attachment_payload(attachment)
                            for attachment in message.attachment_ids],
        }

    def _mention_avatar_url(self, partner):
        """Signed avatar URL whose `t` token is scoped to one record, one field and an expiry, never the Bearer token."""
        return "%s/api/mobile/v1/partners/%s/avatar?t=%s" % (
            self._api_base_url(), partner.id,
            self._image_link_token(partner, MENTION_AVATAR_FIELD))

    def _mention_payload(self, partner, include_email):
        """Serialise one mention candidate; `id` is the res.partner id that `message_post(partner_ids=...)` expects."""
        # `partner_share` is stored and computed as "no user, or every user is a share user".
        try:
            internal_user = partner.user_ids.filtered(lambda u: not u.share)[:1]
        except AccessError:
            internal_user = None
        return {
            "id": partner.id,
            "name": partner.name or "",
            "email": (partner.email or None) if include_email else None,
            "image_url": self._mention_avatar_url(partner),
            "is_internal_user": not partner.partner_share,
            "user_id": internal_user.id if internal_user else None,
        }

    @main.http.route("/api/mobile/v1/log-note/mention-suggestions",
                     type="http", auth="none", methods=["GET"], csrf=False)
    def log_note_mention_suggestions(self, **kwargs):
        """People the caller may @mention, filtered by optional `search` and `limit` (default 20, max 50).
        Order is Odoo's mention priority and must be kept; no paging because the search runs three limited queries.
        """
        user, err = self._authenticate_log_note()
        if err:
            return err

        search = (kwargs.get("search") or "").strip()

        try:
            limit = int(kwargs.get("limit", DEFAULT_MENTION_LIMIT))
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_pagination",
                              message="limit must be an integer.", status=400)
        if limit < 1:
            return self._json(success=False, code="invalid_pagination",
                              message="limit must be greater than 0.", status=400)
        limit = min(limit, MAX_MENTION_LIMIT)

        partner_model = request.env["res.partner"]
        try:
            # Both helpers are @api.model on res.partner and run as the logged-in user (no sudo).
            domain = partner_model._get_mention_suggestions_domain(search)
            partners = partner_model._search_mention_suggestions(
                domain, limit + 1)
        except AccessError:
            return self._json(success=False, code="mention_access_denied",
                              message="You are not allowed to look up contacts.",
                              status=403)

        has_more = len(partners) > limit
        partners = partners[:limit]

        # Odoo only discloses partner emails to internal users.
        include_email = not user.share

        return self._json(
            success=True,
            message="Mention suggestions loaded successfully.",
            data={
                "search": search,
                "limit": limit,
                "total": len(partners),
                "has_more": has_more,
                "suggestions": [
                    self._mention_payload(partner, include_email)
                    for partner in partners
                ],
            },
        )

    @main.http.route("/api/mobile/v1/log-note/messages",
                     type="http", auth="none", methods=["GET"], csrf=False)
    def log_note_messages(self, **kwargs):
        """The chatter of one record, newest first, paginated with `page`/`limit` (default 30, max 50).
        `source` is an allowlist (expense, timeoff, payslip, calendar), never a model name.
        """
        user, err = self._authenticate_log_note()
        if err:
            return err

        thread, err = self._resolve_thread(
            user, (kwargs.get("source") or "").strip(), kwargs.get("id"))
        if err:
            return err

        try:
            page = int(kwargs.get("page", 1))
            limit = int(kwargs.get("limit", DEFAULT_MESSAGE_LIMIT))
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_pagination",
                              message="page and limit must be integers.",
                              status=400)
        if page < 1 or limit < 1:
            return self._json(success=False, code="invalid_pagination",
                              message="page and limit must be greater than 0.", status=400)
        limit = min(limit, MAX_MESSAGE_LIMIT)

        try:
            # Same thread domain Odoo's own chatter applies when fetching messages.
            message_model = request.env["mail.message"]
            if thread.env.su:
                message_model = message_model.sudo()
            domain = [
                ("res_id", "=", thread.id),
                ("model", "=", thread._name),
                ("message_type", "!=", "user_notification"),
                "|",
                ("attachment_ids", "!=", False),
                "&",
                ("body", "!=", False),
                ("body", "not in", EMPTY_BODY_VALUES),
            ]
            total = message_model.search_count(domain)
            messages = message_model.search(
                domain, order="id desc", limit=limit,
                offset=(page - 1) * limit)
        except AccessError:
            return self._thread_not_found((kwargs.get("source") or "").strip())

        own_partner = user.partner_id
        tz = self._mobile_timezone(user)

        # Gate 1 of `_resolve_own_note`, evaluated ONCE for the whole page, not per message.
        _writable_thread, write_err = self._resolve_thread(
            user, (kwargs.get("source") or "").strip(), kwargs.get("id"),
            write=True)
        thread_writable = write_err is None

        # The query orders newest-first, so the newest entry is the first item.
        ordered = messages

        return self._json(
            success=True,
            message="Log notes loaded successfully.",
            data={
                "source": kwargs.get("source"),
                "record": self._record_payload(thread),
                "timezone": str(tz),
                "pagination": {
                    "page": page,
                    "limit": limit,
                    "total": total,
                    "has_next": page * limit < total,
                    "has_previous": page > 1,
                },
                "messages": [
                    self._message_payload(message, own_partner, tz,
                                          thread_writable=thread_writable)
                    for message in ordered
                ],
            },
        )

    @main.http.route("/api/mobile/v1/log-note/messages",
                     type="http", auth="none", methods=["POST"], csrf=False,
                     readonly=False)
    def log_note_create(self, **kwargs):
        """Post one internal log note from a `body_parts` array with mention partner ids, via JSON or multipart.
        Files use the multipart field `attachment` (aliases `file`, `attachments`, `attachments[]`).
        """
        user, err = self._authenticate_log_note()
        if err:
            return err
        payload = self._create_log_note_payload(kwargs)
        thread, err = self._resolve_thread(
            user, (payload.get("source") or "").strip(), payload.get("id"),
            write=True)
        if err:
            return err

        body, mention_ids, problem = self._log_note_body(payload.get("body_parts"))
        if problem:
            return self._json(success=False, code="invalid_body_parts",
                              message=problem, status=400)

        attachments, err = self._log_note_attachments()
        if err:
            return err

        if self._log_note_is_empty(body, mention_ids) and not attachments:
            return self._json(success=False, code="empty_log_note",
                              message="A log note needs text, a mention, or an attachment.",
                              status=400)

        try:
            with request.env.cr.savepoint():
                message = thread.message_post(
                    body=body,
                    body_is_html=True,
                    message_type="comment",
                    subtype_xmlid="mail.mt_note",
                    # Payslip threads are resolved under a narrowly scoped sudo, so the author is set explicitly.
                    author_id=user.partner_id.id,
                    partner_ids=list(set(mention_ids)),
                    attachments=attachments,
                )
        except AccessError:
            return self._thread_not_found((payload.get("source") or "").strip())
        except UserError as exc:
            return self._json(success=False, code="log_note_create_failed",
                              message=str(exc), status=400)

        return self._json(
            success=True,
            message="Log note created successfully.",
            data={
                "source": payload.get("source"),
                "record": {"model": thread._name, "id": thread.id},
                "message": self._message_payload(
                    message, user.partner_id, self._mobile_timezone(user)),
            },
            status=201,
        )

    @main.http.route(["/api/mobile/v1/log-note/messages/<message_id>",
                      "/api/mobile/v1/log-note/messages"],
                     type="http", auth="none", methods=["PATCH"], csrf=False,
                     readonly=False)
    def log_note_update(self, message_id=None, **kwargs):
        """Edit the caller's own log note with the same payload as create; new files are added.
        `existing_attachments` lists files to keep (omitted keeps all, [] clears); dropped files are deleted.
        """
        user, err = self._authenticate_log_note()
        if err:
            return err

        payload = self._create_log_note_payload(kwargs)
        raw_id = message_id if message_id is not None else payload.get("message_id")
        message, thread, source, err = self._resolve_own_note(user, raw_id, "edit")
        if err:
            return err

        body, mention_ids, problem = self._log_note_body(payload.get("body_parts"))
        if problem:
            return self._json(success=False, code="invalid_body_parts",
                              message=problem, status=400)

        new_files, err = self._log_note_attachments()
        if err:
            return err

        keep_ids, err = self._parse_existing_attachment_ids(payload)
        if err:
            return err

        # sudo AFTER the three gates in `_resolve_own_note`, which are the real authorisation.
        scoped = message.sudo()
        posting = thread.sudo()
        current = scoped.attachment_ids
        if keep_ids is None:
            kept = current
            dropped = current.browse()
        else:
            kept = current.filtered(lambda a: a.id in keep_ids)
            dropped = current - kept

        if (self._log_note_is_empty(body, mention_ids)
                and not kept and not new_files):
            return self._json(
                success=False, code="empty_log_note",
                message="A log note needs text, a mention, or an attachment.",
                status=400)

        try:
            with request.env.cr.savepoint():
                # Created directly rather than through mail's attachment helpers.
                created = request.env["ir.attachment"].sudo().create([{
                    "name": name,
                    "raw": content,
                    "mimetype": info.get("mimetype"),
                    "res_model": thread._name,
                    "res_id": thread.id,
                } for name, content, info in new_files]) if new_files else []
                final_ids = kept.ids + (created.ids if new_files else [])
                posting._message_update_content(
                    scoped, body=body if body else "",
                    attachment_ids=final_ids,
                    partner_ids=list(set(mention_ids)),
                )
                # Whatever the caller dropped is deleted outright.
                dropped = dropped.exists()
                if dropped:
                    dropped.unlink()
        except AccessError:
            return self._json(success=False, code="message_update_denied",
                              message="You do not have permission to edit this message.",
                              status=403)
        except UserError as exc:
            return self._json(success=False, code="log_note_update_failed",
                              message=str(exc), status=400)
        except Exception:
            _logger.exception("Unable to edit log note %s for user %s",
                              raw_id, user.id)
            return self._json(success=False, code="log_note_update_failed",
                              message="Unable to edit this message.", status=400)

        if not scoped.exists():
            # `_message_update_content` already cleans up a note edited down to nothing.
            return self._json(success=True, message="Log note deleted successfully.",
                              data={"id": int(raw_id), "source": source,
                                    "record": {"model": thread._name, "id": thread.id},
                                    "deleted": True})

        return self._json(success=True, message="Log note updated successfully.", data={
            "source": source,
            "record": {"model": thread._name, "id": thread.id},
            "message": self._message_payload(
                message, user.partner_id, self._mobile_timezone(user)),
        })

    @main.http.route(["/api/mobile/v1/log-note/messages/<message_id>",
                      "/api/mobile/v1/log-note/messages"],
                     type="http", auth="none", methods=["DELETE"], csrf=False,
                     readonly=False)
    def log_note_delete(self, message_id=None, **kwargs):
        """Delete the caller's own log note, by path id or `?message_id=`, after the `_resolve_own_note` gates.
        Attachments are deleted too, otherwise they would resurface as the record's own files.
        """
        user, err = self._authenticate_log_note()
        if err:
            return err

        raw_id = message_id if message_id is not None else kwargs.get("message_id")
        message, thread, source, err = self._resolve_own_note(user, raw_id)
        if err:
            return err

        # Read before the delete -- afterwards these raise MissingError.
        deleted_id = message.id
        # sudo AFTER the three gates in `_resolve_own_note`, which are the real authorisation.
        scoped = message.sudo()

        try:
            # Savepoint: a failure part-way must not leave a message whose attachments are gone.
            with request.env.cr.savepoint():
                # Attachments first, while the message still exists.
                scoped.attachment_ids.unlink()
                scoped.unlink()
        except AccessError:
            return self._json(success=False, code="message_delete_denied",
                              message="You do not have permission to delete this message.",
                              status=403)
        except UserError as exc:
            return self._json(success=False, code="log_note_delete_failed",
                              message=str(exc), status=400)
        except Exception:
            _logger.exception("Unable to delete log note %s for user %s",
                              message_id, user.id)
            return self._json(success=False, code="log_note_delete_failed",
                              message="Unable to delete this message.", status=400)

        return self._json(success=True, message="Log note deleted successfully.", data={
            "id": deleted_id,
            "source": source,
            "record": {"model": thread._name, "id": thread.id},
        })

    @main.http.route("/api/mobile/v1/log-note/attachments/<attachment_id>",
                     type="http", auth="none", methods=["GET"], csrf=False)
    def log_note_attachment(self, attachment_id, **kwargs):
        """Stream a log-note file after re-checking the parent thread's access for the Bearer caller.
        Images go through the image pipeline so `?width=&height=` thumbnails work.
        """
        try:
            attachment_id = int(attachment_id)
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_attachment_id",
                              message="attachment_id must be an integer.",
                              status=400)

        user, err = self._authenticate_log_note()
        if err:
            return err

        attachment = request.env["ir.attachment"].sudo().browse(attachment_id)
        if not attachment.exists():
            return self._json(success=False, code="attachment_not_found",
                              message="Attachment not found.", status=404)

        source, record_id = self._attachment_thread_source(attachment)
        if not source:
            return self._json(success=False, code="attachment_not_found",
                              message="Attachment not found.", status=404)
        thread, err = self._resolve_thread(user, source, record_id)
        if err or not thread:
            # Do not reveal whether a global attachment id exists when its parent is inaccessible.
            return self._json(success=False, code="attachment_not_found",
                              message="Attachment not found.", status=404)

        if self._log_note_attachment_kind(attachment.mimetype) == "image":
            response = self._image_stream_response(
                attachment, ATTACHMENT_FIELD, query=kwargs,
                not_found_code="attachment_not_found",
                not_found_message="This attachment is no longer available.")
            response.headers["Cache-Control"] = "private, no-store"
            return response

        try:
            stream = request.env["ir.binary"]._get_stream_from(
                attachment, ATTACHMENT_FIELD)
        except (AccessError, FileNotFoundError, UserError):
            return self._json(success=False, code="attachment_not_found",
                              message="This attachment is no longer available.",
                              status=404)
        stream.public = False
        response = stream.get_response()
        response.headers["Cache-Control"] = "private, no-store"
        return response

    @main.http.route("/api/mobile/v1/partners/<partner_id>/avatar",
                     type="http", auth="none", methods=["GET"], csrf=False)
    def partner_avatar(self, partner_id, **kwargs):
        """Stream a mention candidate's avatar via a signed `?t=` token or a Bearer token.
        `<partner_id>` is not `<int:>` so malformed ids still get a JSON 404 instead of Odoo's HTML page.
        """
        try:
            partner_id = int(partner_id)
        except (TypeError, ValueError):
            return self._json(success=False, code="invalid_partner_id",
                              message="partner_id must be an integer.",
                              status=400)

        link_token = request.httprequest.args.get("t")
        if link_token:
            target = request.env["res.partner"].browse(partner_id)
            if not target.exists() or not self._verify_image_token(
                    target, MENTION_AVATAR_FIELD, link_token):
                return self._json(success=False, code="avatar_token_invalid",
                                  message="This avatar link is invalid or has expired.",
                                  status=403)
            # This request authenticates no user (that is the point), so stream as the public user.
            public_uid = request.env.ref("base.public_user").id
            target = target.with_env(request.env(user=public_uid)).sudo()
            return self._image_stream_response(
                target, MENTION_AVATAR_FIELD, query=kwargs,
                not_found_code="avatar_not_found",
                not_found_message="No avatar is available.")

        user, err = self._authenticate_log_note()
        if err:
            return err

        target = request.env["res.partner"].browse(partner_id)
        try:
            if not target.exists():
                return self._json(success=False, code="partner_not_found",
                                  message="Contact not found.", status=404)
        except AccessError:
            # Do not distinguish "does not exist" from "not visible to you": that would leak existence.
            return self._json(success=False, code="partner_not_found",
                              message="Contact not found.", status=404)

        return self._image_stream_response(
            target, MENTION_AVATAR_FIELD, query=kwargs,
            not_found_code="avatar_not_found",
            not_found_message="No avatar is available.")
