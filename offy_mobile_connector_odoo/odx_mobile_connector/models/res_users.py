# -*- coding: utf-8 -*-
import base64

from odoo import _, models, fields, api, Command
from odoo.exceptions import ValidationError
from odoo.tools.mimetypes import guess_mimetype

class ResUsers(models.Model):
    _inherit = 'res.users'

    # Small explicit allow-list: a policy boundary on the user's own private profile, not an ACL.
    _MOBILE_OWN_PRIVATE_PROFILE_FIELDS = (
        'private_email', 'private_phone', 'birthday', 'sex', 'marital',
        'place_of_birth', 'private_street', 'private_street2', 'private_city',
        'private_state_id', 'private_zip', 'private_country_id', 'certificate',
        'study_field',
    )
    _MOBILE_OWN_PRIVATE_PROFILE_SELECTION_FIELDS = (
        'sex', 'marital', 'certificate',
    )

    def _set_password(self):
        """Changing the password signs every mobile device out; core only invalidates web sessions.
        Hooked here so every password path is covered; no try/except so a failure rolls both back."""
        super()._set_password()
        self._mobile_revoke_sessions(reason="password_changed")

    def _mobile_revoke_sessions(self, reason="password_changed"):
        """Sign these users out of the mobile app on every device, including all push tokens.
        `odx_mobile_api` extends this to revoke its access and refresh tokens."""
        if not self.ids:
            return
        tokens = self.env["mobile.device.token"].sudo().search([
            ("user_id", "in", self.ids),
            ("active", "=", True),
        ])
        if tokens:
            tokens.write({
                "active": False,
                "removed_reason": reason,
                "removed_at": fields.Datetime.now(),
            })
        # Short-lived websocket auth tickets: an unconsumed one would still
        # buy a socket connection after the session behind it is gone.
        self.env["mobile.realtime.ticket"].sudo().search([
            ("user_id", "in", self.ids),
            ("used_at", "=", False),
        ]).unlink()

    def _mobile_company_ids(self):
        """Companies listed in the user's mobile company switcher: where they are employed, not `company_ids`.
        Falls back to `company_ids` when unemployed; sudo() covers only the employee lookup."""
        self.ensure_one()
        allowed = self.sudo().company_ids
        employed_ids = set(
            self.env["hr.employee"].sudo()
            .search([("user_id", "=", self.id),
                     ("company_id", "in", allowed.ids)])
            .mapped("company_id.id")
        )
        return [cid for cid in allowed.ids if cid in employed_ids] or allowed.ids

    def _mobile_is_multi_company(self):
        """Whether the app shows this user a company switcher; gates company-labelled notifications."""
        return len(self._mobile_company_ids()) > 1

    @api.model
    def _mobile_own_private_profile_values(self):
        """Return the allow-listed private data for the current user only.
        The sudo lookup is pinned to ``env.user.id`` and never takes an id from the client."""
        # Company-scoped, via the one shared resolver.
        employee = self._mobile_own_employee()
        values = {}
        if not employee:
            return values

        for field_name in self._MOBILE_OWN_PRIVATE_PROFILE_FIELDS:
            if field_name not in employee._fields:
                continue
            value = employee[field_name]
            if employee._fields[field_name].type == 'many2one':
                values[field_name] = value.name if value else None
            else:
                values[field_name] = value or None

        for field_name in self._MOBILE_OWN_PRIVATE_PROFILE_SELECTION_FIELDS:
            value = values.get(field_name)
            if not value or field_name not in employee._fields:
                continue
            selection = dict(
                employee._fields[field_name]._description_selection(employee.env))
            values['%s_label' % field_name] = selection.get(value, value)
        return values

    # Work-tab values that live on hr.employee rather than hr.employee.public.
    _MOBILE_OWN_WORK_PROFILE_FIELDS = ('contract_date_start',)

    # Tried in order for the IFSC/routing code; the first one that exists and has a value wins.
    _MOBILE_BANK_IFSC_FIELDS = ('l10n_in_ifsc_code', 'ifsc_code', 'bic')

    @api.model
    def _mobile_own_work_profile_values(self):
        """Allow-listed work data (contract date, bank details) for the current user only.
        Uses the same self-pinned sudo bridge, since employees have no read ACL on `hr.employee`."""
        employee = self._mobile_own_employee()
        values = {'contract_date_start': None, 'bank_accounts': []}
        if not employee:
            return values

        for field_name in self._MOBILE_OWN_WORK_PROFILE_FIELDS:
            if field_name in employee._fields:
                values[field_name] = employee[field_name] or None

        # Primary account first, then the others: the profile shows more than one account.
        accounts = employee.primary_bank_account_id | employee.bank_account_ids
        for account in accounts:
            ifsc = None
            for field_name in self._MOBILE_BANK_IFSC_FIELDS:
                if field_name in account._fields and account[field_name]:
                    ifsc = account[field_name]
                    break
            if not ifsc and account.bank_id and 'bic' in account.bank_id._fields:
                ifsc = account.bank_id.bic or None
            values['bank_accounts'].append({
                'bank_name': account.bank_id.name if account.bank_id else None,
                'account_number': account.acc_number or None,
                'ifsc_code': ifsc or None,
            })
        return values

    # Employee document Binary fields exposed to the mobile Documents card.
    _MOBILE_EMPLOYEE_DOCUMENT_FIELDS = (
        ('id_card', 'id_card'),
        ('work_permit', 'has_work_permit'),
        ('driving_license', 'driving_license'),
    )

    def _mobile_own_employee(self):
        """The current user's own employee record in the active company, built from ``self.env.uid``."""
        return self.env['hr.employee'].sudo().search(
            [('user_id', '=', self.env.uid),
             ('company_id', 'in', self.env.context.get(
                 'allowed_company_ids', self.env.company.ids))], limit=1)

    def _mobile_read_document_field(self, employee, field_name):
        """Decode one Binary document field, or None when there is no file."""
        if not employee or field_name not in employee._fields:
            return None
        raw = employee[field_name]
        if not raw:
            return None
        try:
            content = base64.b64decode(raw)
        except (TypeError, ValueError):
            return None
        if not content:
            return None
        # Binary fields carry no filename, so the type is sniffed from the bytes.
        return {'content': content,
                'mimetype': guess_mimetype(content),
                'size': len(content)}

    @api.model
    def _mobile_own_employee_documents(self):
        """Employee documents the current user has on file; empty fields are omitted.
        Returns dicts with `code`, `name`, `content` (bytes), `mimetype` and `size`, in registry order."""
        employee = self._mobile_own_employee()
        if not employee:
            return []
        # One `fields_get` for the whole set: labels are Odoo's own translated field strings.
        field_names = [fname for _code, fname in
                       self._MOBILE_EMPLOYEE_DOCUMENT_FIELDS
                       if fname in employee._fields]
        labels = employee.fields_get(field_names, attributes=['string'])

        documents = []
        for code, field_name in self._MOBILE_EMPLOYEE_DOCUMENT_FIELDS:
            document = self._mobile_read_document_field(employee, field_name)
            if not document:
                continue
            documents.append({
                'code': code,
                'name': labels.get(field_name, {}).get('string') or code,
                **document,
            })
        return documents

    @api.model
    def _mobile_own_employee_document(self, code):
        """One employee document by its stable API code, or None.
        `code` is resolved through the registry so a hostile value never reaches `employee[...]`."""
        field_name = dict(self._MOBILE_EMPLOYEE_DOCUMENT_FIELDS).get(code)
        if not field_name:
            return None
        employee = self._mobile_own_employee()
        document = self._mobile_read_document_field(employee, field_name)
        if not document:
            return None
        label = employee.fields_get([field_name], attributes=['string'])
        return {'code': code,
                'name': label.get(field_name, {}).get('string') or code,
                **document}

    @api.model
    def _mobile_own_id_card(self):
        """Deprecated delegate for `/profile/id-card`; use `_mobile_own_employee_document('id_card')`."""
        return self._mobile_own_employee_document('id_card')

    # No default: a default would trigger the inverse on create and strip groups passed in group_ids.
    mobile_access_level = fields.Selection([
        ('none', 'No Access'),
        ('viewer', 'Mobile App View Access'),
        ('manager', 'Mobile App Manager'),
        ('admin', 'Mobile App Administrator'),
    ], string="Access Level",
        compute="_compute_mobile_access_level", inverse="_inverse_mobile_access_level",
        help="Backend access level for the OFFY Connector. "
             "'No Access' means the user can neither view nor manage connector data.")

    mobile_user = fields.Boolean(
        string="Mobile User",
        compute="_compute_mobile_user",
        inverse="_inverse_mobile_user",
        help="Check this box to allow this user to access the mobile application."
    )

    mobile_feature_access_ids = fields.One2many(
        comodel_name="mobile.user.feature",
        inverse_name="user_id",
        string="Mobile Feature Access",
        help="Features this user may use in the mobile app, with full access. "
             "Features not listed are hidden from the user.",
    )

    is_mobile_restricted_user = fields.Boolean(
        string="Portal/Public User",
        compute="_compute_is_mobile_restricted_user",
        help="Technical field: true for real portal or public users, who may "
             "never be granted any OFFY Connector group. Drives the "
             "OFFY Connector fields' visibility in the Users form.",
    )

    # All groups this connector defines; portal/public users may not hold any of them.
    _MOBILE_INTERNAL_ONLY_GROUP_XMLIDS = (
        'odx_mobile_connector.group_mobile_user',
        'odx_mobile_connector.group_mobile_viewer',
        'odx_mobile_connector.group_mobile_manager',
        'odx_mobile_connector.group_mobile_admin',
    )

    # Groups marking a user as external (portal/public), who may not use the mobile app.
    _MOBILE_RESTRICTED_GROUP_XMLIDS = (
        'base.group_portal',
        'base.group_public',
    )

    def _mobile_connector_groups(self):
        groups = self.env['res.groups']
        for xmlid in self._MOBILE_INTERNAL_ONLY_GROUP_XMLIDS:
            group = self.env.ref(xmlid, raise_if_not_found=False)
            if group:
                groups |= group
        return groups

    def _mobile_restricted_groups(self):
        groups = self.env['res.groups']
        for xmlid in self._MOBILE_RESTRICTED_GROUP_XMLIDS:
            group = self.env.ref(xmlid, raise_if_not_found=False)
            if group:
                groups |= group
        return groups

    @api.depends('group_ids')
    def _compute_is_mobile_restricted_user(self):
        restricted = self._mobile_restricted_groups()
        for user in self:
            user.is_mobile_restricted_user = bool(restricted and (restricted & user.all_group_ids))

    @api.constrains('group_ids')
    def _check_mobile_groups_are_internal_only(self):
        """Portal and public users must never hold any OFFY Connector group.
        A constraint on `group_ids` covers every grant path (imports, RPC, raw widget), unlike the view."""
        mobile_groups = self._mobile_connector_groups()
        if not mobile_groups:
            return
        restricted_groups = self._mobile_restricted_groups()
        if not restricted_groups:
            return
        for user in self:
            held = mobile_groups & user.group_ids
            if held and (restricted_groups & user.all_group_ids):
                raise ValidationError(_(
                    "%(user)s cannot be granted %(groups)s: the Mobile "
                    "Connector is for internal use only. Portal and public "
                    "users must never be given mobile app access or backend "
                    "configuration access to it.",
                    user=user.name,
                    groups=", ".join(held.mapped('name')),
                ))

    @api.depends('group_ids')
    def _compute_mobile_access_level(self):
        group_viewer = self.env.ref('odx_mobile_connector.group_mobile_viewer', raise_if_not_found=False)
        group_manager = self.env.ref('odx_mobile_connector.group_mobile_manager', raise_if_not_found=False)
        group_admin = self.env.ref('odx_mobile_connector.group_mobile_admin', raise_if_not_found=False)
        for user in self:
            groups = user.all_group_ids
            if group_admin and group_admin in groups:
                user.mobile_access_level = 'admin'
            elif group_manager and group_manager in groups:
                user.mobile_access_level = 'manager'
            elif group_viewer and group_viewer in groups:
                user.mobile_access_level = 'viewer'
            else:
                user.mobile_access_level = 'none'

    def _inverse_mobile_access_level(self):
        group_viewer = self.env.ref('odx_mobile_connector.group_mobile_viewer', raise_if_not_found=False)
        group_manager = self.env.ref('odx_mobile_connector.group_mobile_manager', raise_if_not_found=False)
        group_admin = self.env.ref('odx_mobile_connector.group_mobile_admin', raise_if_not_found=False)
        if not group_viewer or not group_manager or not group_admin:
            return
        levels = {group_admin: 'admin', group_manager: 'manager', group_viewer: 'viewer'}
        for user in self:
            current = next((lvl for grp, lvl in levels.items() if grp in user.all_group_ids), 'none')
            if current == user.mobile_access_level:
                continue
            commands = [
                Command.unlink(group_viewer.id),
                Command.unlink(group_manager.id),
                Command.unlink(group_admin.id),
            ]
            if user.mobile_access_level == 'admin':
                commands.append(Command.link(group_admin.id))
            elif user.mobile_access_level == 'manager':
                commands.append(Command.link(group_manager.id))
            elif user.mobile_access_level == 'viewer':
                commands.append(Command.link(group_viewer.id))
            user.write({'group_ids': commands})

    @api.depends('group_ids')
    def _compute_mobile_user(self):
        group = self.env.ref('odx_mobile_connector.group_mobile_user', raise_if_not_found=False)
        for user in self:
            user.mobile_user = group in user.group_ids if group else False

    def _inverse_mobile_user(self):
        group = self.env.ref('odx_mobile_connector.group_mobile_user', raise_if_not_found=False)
        if not group:
            return
        for user in self:
            if user.mobile_user:
                user.write({'group_ids': [Command.link(group.id)]})
            else:
                user.write({'group_ids': [Command.unlink(group.id)]})

    def _mobile_user_group(self):
        return self.env.ref(
            'odx_mobile_connector.group_mobile_user', raise_if_not_found=False
        )

    def _grant_all_feature_access(self):
        """Attach the user to every feature (full access) they don't have yet."""
        UF = self.env['mobile.user.feature'].sudo()
        features = self.env['mobile.feature'].sudo().with_context(
            active_test=False
        ).search([])
        for user in self:
            missing = features - UF.search([('user_id', '=', user.id)]).feature_id
            if missing:
                UF.create([
                    {'user_id': user.id, 'feature_id': f.id} for f in missing
                ])

    def _revoke_all_feature_access(self):
        """Remove all of the user's feature-access rows."""
        self.env['mobile.user.feature'].sudo().search(
            [('user_id', 'in', self.ids)]
        ).unlink()

    @api.model_create_multi
    def create(self, vals_list):
        users = super().create(vals_list)
        group = users._mobile_user_group()
        if group:
            users.filtered(lambda u: group in u.group_ids)._grant_all_feature_access()
        return users

    def write(self, vals):
        """Sync feature-access rows only on Mobile User grant/revoke transitions.
        Plain edits leave rows alone, so manual per-feature removals stick."""
        group = self._mobile_user_group()
        was_member = {u.id: (group in u.group_ids) for u in self} if group else {}
        res = super().write(vals)
        if group and ('group_ids' in vals or 'mobile_user' in vals):
            changed = self.browse()
            for user in self:
                now_member = group in user.group_ids
                if now_member and not was_member.get(user.id):
                    user._grant_all_feature_access()
                    changed |= user
                elif was_member.get(user.id) and not now_member:
                    user._revoke_all_feature_access()
                    changed |= user
            # Notify once for the whole change set after the feature rows are granted/revoked.
            if changed:
                self.env["mobile.sync.service"].notify_access(
                    changed, reason="mobile_user_group_changed")
        return res
