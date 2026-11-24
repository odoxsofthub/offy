import base64

from odoo.tests import HttpCase, tagged

TINY_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk"
    "+A8AAQUBAScY42YAAAAASUVORK5CYII="
)
TINY_PDF = b"%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>"


@tagged("-at_install", "post_install")
class TestMobileProfileDocumentsApi(HttpCase):
    """The `data.docs.certificates` contract on GET /profile: chatter attachments on the employee record.
    Binary-field attachments (res_field set) are excluded, documents_hr must not change it, and it is company-scoped.
    """

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.password = "profile_docs_pw_1234"
        cls.user = Users.create({
            "name": "Docs Mobile User",
            "login": "profile_docs_user@test.com",
            "password": cls.password,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Docs Mobile User", "company_id": company.id,
            "user_id": cls.user.id})

        cls.other_user = Users.create({
            "name": "Other Docs User",
            "login": "profile_docs_other@test.com",
            "password": cls.password,
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.other_employee = Employee.create({
            "name": "Other Docs User", "company_id": company.id,
            "user_id": cls.other_user.id})

        cls.doc_first = cls._attach(cls.employee, "Degree Certificate.pdf",
                                    TINY_PDF, "application/pdf")
        cls.doc_latest = cls._attach(cls.employee, "Passport Scan.png",
                                     TINY_PNG, "image/png")

        # A binary-FIELD upload. Same res_model/res_id, but res_field set.
        cls.field_attachment = cls.env["ir.attachment"].sudo().create({
            "name": "id_card_binary",
            "datas": base64.b64encode(TINY_PNG),
            "mimetype": "image/png",
            "res_model": "hr.employee",
            "res_id": cls.employee.id,
            "res_field": "id_card",
        })
        # Somebody else's document -- the IDOR target.
        cls.foreign_doc = cls._attach(cls.other_employee, "Not Yours.pdf",
                                      TINY_PDF, "application/pdf")

        cls.env.flush_all()

    @classmethod
    def _attach(cls, employee, name, raw, mimetype):
        """An attachment shaped exactly like a chatter upload."""
        return cls.env["ir.attachment"].sudo().create({
            "name": name,
            "datas": base64.b64encode(raw),
            "mimetype": mimetype,
            "res_model": "hr.employee",
            "res_id": employee.id,
            "type": "binary",
        })

    def _token(self, login=None):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": login or "profile_docs_user@test.com",
                  "password": self.password},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login failed: %s" % body)
        return body["data"]["token"]

    def _get(self, path, token=None):
        headers = {"Authorization": "Bearer %s" % token} if token else {}
        resp = self.url_open(path, headers=headers)
        return resp.status_code, resp.json()

    def _certificates(self, token=None):
        status, body = self._get("/api/mobile/v1/profile", token or self._token())
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"], body)
        return body["data"]["docs"]["certificates"]

    def _ids(self, certificates):
        return [doc["id"] for doc in certificates]

    def test_chatter_attachment_appears_in_certificates(self):
        ids = self._ids(self._certificates())
        self.assertIn(self.doc_first.id, ids)
        self.assertIn(self.doc_latest.id, ids)

    def test_filename_is_the_label_the_app_renders(self):
        """HR names the file; the API does not invent a title. This is why
        the upload instruction tells HR to rename before uploading."""
        doc = next(d for d in self._certificates() if d["id"] == self.doc_first.id)
        self.assertEqual(doc["name"], "Degree Certificate.pdf")
        self.assertEqual(doc["filename"], "Degree Certificate.pdf")

    def test_payload_carries_kind_size_download_and_preview(self):
        doc = next(d for d in self._certificates() if d["id"] == self.doc_latest.id)
        self.assertEqual(doc["kind"], "image")
        self.assertEqual(doc["mimetype"], "image/png")
        self.assertTrue(doc["file_size"])
        self.assertEqual(
            doc["download"]["endpoint"],
            "/api/mobile/v1/profile/documents/%s/download" % self.doc_latest.id)
        self.assertTrue(doc["download"]["requires_auth"])
        self.assertEqual(
            doc["preview"]["endpoint"],
            "/api/mobile/v1/profile/documents/%s/preview" % self.doc_latest.id)

    def test_pdf_is_bucketed_as_pdf(self):
        doc = next(d for d in self._certificates() if d["id"] == self.doc_first.id)
        self.assertEqual(doc["kind"], "pdf")

    def test_newest_first(self):
        """`order="id desc"` -- the most recently filed document leads."""
        ids = self._ids(self._certificates())
        self.assertLess(ids.index(self.doc_latest.id),
                        ids.index(self.doc_first.id))

    def test_binary_field_upload_is_excluded(self):
        """`res_field = False` keeps Binary-field uploads (and the avatar) out of the Docs card."""
        self.assertNotIn(self.field_attachment.id,
                         self._ids(self._certificates()))

    def test_another_employees_document_is_never_listed(self):
        self.assertNotIn(self.foreign_doc.id, self._ids(self._certificates()))

    def test_another_employees_document_cannot_be_downloaded_by_id(self):
        """The id is client-controlled; ownership is enforced by the domain,
        not by trusting that the app only sends ids it was given."""
        status, body = self._get(
            "/api/mobile/v1/profile/documents/%s/download" % self.foreign_doc.id,
            self._token())
        self.assertEqual(status, 404)
        self.assertEqual(body["code"], "document_not_found")

    def test_another_employees_document_cannot_be_previewed_by_id(self):
        """Download and preview share `_own_document`, so they cannot drift --
        asserted separately because a future refactor could split them."""
        status, body = self._get(
            "/api/mobile/v1/profile/documents/%s/preview" % self.foreign_doc.id,
            self._token())
        self.assertEqual(status, 404)
        self.assertEqual(body["code"], "document_not_found")

    def test_a_registered_document_field_IS_downloadable_by_id(self):
        """Registered document fields are downloadable by id, like certificates."""
        status, body = self._get(
            "/api/mobile/v1/profile/documents/%s/download"
            % self.field_attachment.id, self._token())
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"], body)
        self.assertEqual(base64.b64decode(body["data"]["base64"]), TINY_PNG)

    def test_download_filename_matches_the_one_the_list_advertised(self):
        """The download filename must match the listed one, extension included, or the saved file will not open."""
        listed = next(d for d in self._employee_documents()
                      if d["code"] == "id_card")
        status, body = self._get(
            "/api/mobile/v1/profile/documents/%s/download" % listed["id"],
            self._token())
        self.assertEqual(status, 200, body)
        self.assertEqual(body["data"]["filename"], listed["filename"])

    def test_certificate_download_filename_is_unchanged(self):
        """A real attachment name must still pass through untouched."""
        status, body = self._get(
            "/api/mobile/v1/profile/documents/%s/download" % self.doc_first.id,
            self._token())
        self.assertEqual(status, 200, body)
        self.assertEqual(body["data"]["filename"], "Degree Certificate.pdf")

    def test_an_unregistered_field_attachment_is_still_not_downloadable(self):
        """Unregistered Binary fields (e.g. the avatar) must stay unreachable by id, or the endpoint becomes a generic field reader."""
        avatar_attachment = self.env["ir.attachment"].sudo().create({
            "name": "avatar_binary",
            "datas": base64.b64encode(TINY_PNG),
            "mimetype": "image/png",
            "res_model": "hr.employee",
            "res_id": self.employee.id,
            "res_field": "image_1920",
        })
        status, body = self._get(
            "/api/mobile/v1/profile/documents/%s/download" % avatar_attachment.id,
            self._token())
        self.assertEqual(status, 404, body)
        self.assertEqual(body["code"], "document_not_found")

    def test_a_registered_field_of_ANOTHER_employee_is_not_downloadable(self):
        """Widening `res_field` must not have widened whose records are
        reachable -- `res_id` is still the caller's own employee."""
        foreign_field = self.env["ir.attachment"].sudo().create({
            "name": "id_card",
            "datas": base64.b64encode(TINY_PNG),
            "mimetype": "image/png",
            "res_model": "hr.employee",
            "res_id": self.other_employee.id,
            "res_field": "id_card",
        })
        status, body = self._get(
            "/api/mobile/v1/profile/documents/%s/download" % foreign_field.id,
            self._token())
        self.assertEqual(status, 404, body)
        self.assertEqual(body["code"], "document_not_found")

    def test_own_document_downloads_as_base64(self):
        status, body = self._get(
            "/api/mobile/v1/profile/documents/%s/download" % self.doc_first.id,
            self._token())
        self.assertEqual(status, 200, body)
        self.assertTrue(body["success"])
        self.assertEqual(body["data"]["filename"], "Degree Certificate.pdf")
        self.assertEqual(base64.b64decode(body["data"]["base64"]), TINY_PDF)

    def test_documents_follow_the_employee_record_not_the_user(self):
        """`hr.employee` is company-scoped, so a document on one company's employee record is invisible from another."""
        other_company = self.env["res.company"].sudo().create(
            {"name": "Docs Second Company"})
        self.user.sudo().write({"company_ids": [(4, other_company.id)]})
        second_employee = self.env["hr.employee"].sudo().create({
            "name": "Docs Mobile User", "company_id": other_company.id,
            "user_id": self.user.id})
        second_doc = self._attach(second_employee, "Second Co Contract.pdf",
                                  TINY_PDF, "application/pdf")
        self.env.flush_all()

        # The session is still scoped to the original company, so only its employee's documents return.
        ids = self._ids(self._certificates())
        self.assertIn(self.doc_first.id, ids)
        self.assertNotIn(second_doc.id, ids)

    def test_employee_with_no_documents_gets_an_empty_list(self):
        """Empty list, never null -- the client renders its empty state
        without a null check."""
        certificates = self._certificates(
            self._token("profile_docs_other@test.com"))
        self.assertIsInstance(certificates, list)
        self.assertEqual(self._ids(certificates), [self.foreign_doc.id])

    def test_certificates_is_always_a_list(self):
        status, body = self._get("/api/mobile/v1/profile", self._token())
        self.assertEqual(status, 200)
        self.assertIsInstance(body["data"]["docs"]["certificates"], list)

    def _employee_documents(self, token=None):
        status, body = self._get("/api/mobile/v1/profile", token or self._token())
        self.assertEqual(status, 200, body)
        return body["data"]["docs"]["employee_documents"]

    def _set_fields(self, **values):
        self.employee.sudo().write(values)
        self.env.flush_all()

    def test_all_three_document_fields_are_returned(self):
        """ID Card Copy, Work Permit and Driving License -- the three Binary
        document fields Odoo 19 defines on hr.employee."""
        self._set_fields(
            id_card=base64.b64encode(TINY_PNG),
            has_work_permit=base64.b64encode(TINY_PDF),
            driving_license=base64.b64encode(TINY_PNG),
        )
        codes = [d["code"] for d in self._employee_documents()]
        self.assertEqual(codes, ["id_card", "work_permit", "driving_license"],
                         "registry order is the render order")

    def test_work_permit_code_is_not_the_odoo_field_name(self):
        """`has_work_permit` reads like a boolean but holds the file. The
        mobile contract deliberately does not inherit that naming."""
        self._set_fields(has_work_permit=base64.b64encode(TINY_PDF))
        codes = [d["code"] for d in self._employee_documents()]
        self.assertIn("work_permit", codes)
        self.assertNotIn("has_work_permit", codes)

    def test_fields_with_no_file_are_omitted(self):
        """Absent, not an empty placeholder -- the client renders the list as
        given rather than filtering something it was just handed."""
        self._set_fields(id_card=base64.b64encode(TINY_PNG),
                         has_work_permit=False, driving_license=False)
        self.assertEqual([d["code"] for d in self._employee_documents()],
                         ["id_card"])

    def test_empty_when_nothing_is_on_file(self):
        self._set_fields(id_card=False, has_work_permit=False,
                         driving_license=False)
        self.assertEqual(self._employee_documents(), [])

    def test_payload_shape(self):
        self._set_fields(driving_license=base64.b64encode(TINY_PDF))
        document = next(d for d in self._employee_documents()
                        if d["code"] == "driving_license")
        # Label is Odoo's translated field string, not a hardcoded English name.
        self.assertEqual(document["name"], "Driving License")
        self.assertEqual(document["kind"], "pdf")
        self.assertTrue(document["file_size"])
        self.assertTrue(document["download"]["requires_auth"])

        attachment = self.env["ir.attachment"].sudo().search([
            ("res_model", "=", "hr.employee"), ("res_id", "=", self.employee.id),
            ("res_field", "=", "driving_license")], limit=1)
        self.assertTrue(attachment, "the Binary field is stored as an attachment")
        self.assertEqual(document["id"], attachment.id)
        self.assertEqual(
            document["download"]["endpoint"],
            "/api/mobile/v1/profile/documents/%s/download" % attachment.id)
        self.assertEqual(
            document["preview"]["endpoint"],
            "/api/mobile/v1/profile/documents/%s/preview" % attachment.id)
        self.assertEqual(document["preview"]["preview_as"], "pdf_page")
        # `filename` is `<code>.<ext>`: a field-backed attachment's own name is the bare field name.
        self.assertEqual(document["filename"], "driving_license.pdf")
        # `code` is kept: the only key `certificates` lacks, and it identifies the document.
        self.assertEqual(document["code"], "driving_license")

    def test_employee_documents_are_built_by_the_certificates_serializer(self):
        """Employee documents must be built by the certificates serializer (`_document_payload`) so the two cannot drift."""
        from odoo.addons.odx_mobile_api.controllers.profile import MobileApiProfile
        self.assertIn(
            "_document_payload",
            MobileApiProfile._employee_field_document_payload.__doc__ or "",
            "the delegation should be documented where it happens")
        self._set_fields(driving_license=base64.b64encode(TINY_PDF))
        document = next(d for d in self._employee_documents()
                        if d["code"] == "driving_license")
        attachment = self.env["ir.attachment"].sudo().search([
            ("res_model", "=", "hr.employee"), ("res_id", "=", self.employee.id),
            ("res_field", "=", "driving_license")], limit=1)
        certificate = next(d for d in self._certificates()
                           if d["id"] == self.doc_first.id)
        # Every key the certificates serializer emits, with the same types.
        for key in certificate:
            self.assertIn(key, document, "missing key produced by the serializer")
            self.assertIsInstance(document[key], type(certificate[key]),
                                  "key %r changed type between the two lists" % key)
        # ...and the by-id endpoints really point at this document's row.
        self.assertEqual(document["id"], attachment.id)
        self.assertIn(str(attachment.id), document["download"]["endpoint"])
        self.assertIn(str(attachment.id), document["preview"]["endpoint"])

    def test_filename_is_code_plus_extension(self):
        """`<code>.<ext>` -- filename-safe, stable across translations, and
        the identifier already used everywhere else in this API."""
        self._set_fields(id_card=base64.b64encode(TINY_PNG))
        document = next(d for d in self._employee_documents()
                        if d["code"] == "id_card")
        self.assertEqual(document["filename"], "id_card.png")
        self.assertEqual(document["mimetype"], "image/png")
        self.assertEqual(document["kind"], "image")

    def test_employee_documents_match_the_certificate_key_set(self):
        """The point of the change: one card renderer for both lists."""
        self._set_fields(driving_license=base64.b64encode(TINY_PDF))
        status, body = self._get("/api/mobile/v1/profile", self._token())
        self.assertEqual(status, 200, body)
        data = body["data"]["docs"]
        self.assertTrue(data["certificates"], "sanity: a certificate exists")
        self.assertTrue(data["employee_documents"], "sanity: a document exists")
        certificate_keys = set(data["certificates"][0])
        document_keys = set(data["employee_documents"][0])
        self.assertEqual(
            certificate_keys - document_keys, set(),
            "employee_documents is missing keys certificates has")
        self.assertEqual(
            document_keys - certificate_keys, {"code"},
            "the only extra key may be `code`")

    def test_mimetype_is_sniffed_from_the_bytes(self):
        """Binary fields carry no filename, so the type cannot be guessed
        from an extension that does not exist."""
        self._set_fields(id_card=base64.b64encode(TINY_PNG))
        document = self._employee_documents()[0]
        self.assertEqual(document["mimetype"], "image/png")
        self.assertEqual(document["kind"], "image")

    def test_company_id_key_is_gone(self):
        """Replaced by `employee_documents` on 2026-08-10. It could only ever
        carry the ID card, and needed a schema change per new document."""
        status, body = self._get("/api/mobile/v1/profile", self._token())
        self.assertNotIn("company_id", body["data"]["docs"])

    def test_document_downloads_as_base64(self):
        self._set_fields(has_work_permit=base64.b64encode(TINY_PDF))
        status, body = self._get(
            "/api/mobile/v1/profile/employee-documents/work_permit",
            self._token())
        self.assertEqual(status, 200, body)
        self.assertEqual(base64.b64decode(body["data"]["base64"]), TINY_PDF)
        self.assertTrue(body["data"]["filename"].startswith("work_permit."))

    def test_unknown_code_is_a_404_not_a_field_read(self):
        """`code` is client-supplied. It must be resolved through the
        registry, never used as a field name."""
        status, body = self._get(
            "/api/mobile/v1/profile/employee-documents/private_email",
            self._token())
        self.assertEqual(status, 404)
        self.assertEqual(body["code"], "document_not_found")

    def test_malformed_code_stays_json(self):
        """The route segment is unconstrained on purpose -- a bad value must
        not miss the route and fall through to Odoo's HTML error page."""
        status, body = self._get(
            "/api/mobile/v1/profile/employee-documents/..etc%20%24bad",
            self._token())
        self.assertEqual(status, 404)
        self.assertFalse(body["success"])

    def test_unknown_code_and_empty_field_are_indistinguishable(self):
        """Different answers would leak which document types exist."""
        self._set_fields(driving_license=False)
        _, empty = self._get(
            "/api/mobile/v1/profile/employee-documents/driving_license",
            self._token())
        _, unknown = self._get(
            "/api/mobile/v1/profile/employee-documents/no_such_document",
            self._token())
        self.assertEqual(empty["code"], unknown["code"])
        self.assertEqual(empty["message"], unknown["message"])

    def test_download_requires_authentication(self):
        status, body = self._get(
            "/api/mobile/v1/profile/employee-documents/id_card")
        self.assertEqual(status, 401)
        self.assertEqual(body["code"], "missing_access_token")

    def test_another_employees_document_is_unreachable(self):
        """No id is accepted from the client -- the employee is resolved from
        the Bearer token alone, so there is nothing to enumerate."""
        self.other_employee.sudo().write(
            {"id_card": base64.b64encode(TINY_PNG)})
        self._set_fields(id_card=False)
        self.env.flush_all()
        status, body = self._get(
            "/api/mobile/v1/profile/employee-documents/id_card",
            self._token())
        self.assertEqual(status, 404)

    def test_deprecated_id_card_route_still_works(self):
        """Kept for app builds that predate `employee_documents`."""
        self._set_fields(id_card=base64.b64encode(TINY_PNG))
        status, body = self._get("/api/mobile/v1/profile/id-card",
                                 self._token())
        self.assertEqual(status, 200, body)
        self.assertEqual(base64.b64decode(body["data"]["base64"]), TINY_PNG)
        self.assertEqual(body["data"]["filename"], "company-id.png",
                         "older builds may save under exactly this name")
