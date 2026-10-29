from odoo.tests import HttpCase, tagged

STUB_PDF = b"%PDF-1.4 stub payslip bytes"


@tagged("-at_install", "post_install")
class TestMobilePayslipDownloadUrl(HttpCase):
    """Payslips are served as a Bearer-authenticated direct-download URL with ownership checks.
    The legacy `/download` route is a raw-PDF alias."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        Users = cls.env["res.users"].sudo()
        Employee = cls.env["hr.employee"].sudo()
        mobile_group = cls.env.ref("odx_mobile_connector.group_mobile_user")
        internal_group = cls.env.ref("base.group_user")
        company = cls.env.ref("base.main_company")

        cls.user = Users.create({
            "name": "Payslip Url User",
            "login": "payslip_url_user@test.com",
            "password": "payslip_url_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.employee = Employee.create({
            "name": "Payslip Url User",
            "company_id": company.id,
            "user_id": cls.user.id,
        })

        cls.other_user = Users.create({
            "name": "Payslip Url Other",
            "login": "payslip_url_other@test.com",
            "password": "payslip_url_pw_1234",
            "group_ids": [(4, mobile_group.id), (4, internal_group.id)],
        })
        cls.other_employee = Employee.create({
            "name": "Payslip Url Other",
            "company_id": company.id,
            "user_id": cls.other_user.id,
        })


    def _token(self, login="payslip_url_user@test.com"):
        resp = self.url_open(
            "/api/mobile/v1/auth/login",
            json={"login": login, "password": "payslip_url_pw_1234"},
            headers={"Content-Type": "application/json"},
        )
        body = resp.json()
        self.assertTrue(body["success"], "login unexpectedly failed: %s" % body)
        return body["data"]["token"]

    def _make_payslip(self, employee=None):
        employee = employee or self.employee
        payslip = self.env["hr.payslip"].sudo().create({
            "name": "Payslip Url Test",
            "employee_id": employee.id,
        })
        # Set state directly: `validated` is the visibility gate; full payroll compute is out of scope.
        self.env.cr.execute(
            "UPDATE hr_payslip SET state = 'validated' WHERE id = %s",
            [payslip.id])
        self.env.invalidate_all()
        return payslip

    def _get(self, path, token=None):
        headers = {"Authorization": "Bearer %s" % token} if token else {}
        return self.url_open(path, headers=headers)

    def _path_of(self, url):
        """Strip the scheme+host so url_open hits the test server."""
        return "/api/" + url.split("/api/", 1)[1]

    def _capture_renders(self):
        """Record the report ref and render context each download path uses; returns a filling list.
        PDFs differ byte-wise (CreationDate, ID), so the renderer is stubbed instead."""
        calls = []
        IrActionsReport = type(self.env["ir.actions.report"])
        original = IrActionsReport._render_qweb_pdf

        def spy(report_self, report_ref, res_ids=None, data=None):
            context = report_self.env.context
            calls.append({
                "report_ref": report_ref,
                "res_ids": list(res_ids or []),
                "lang": context.get("lang"),
                "allowed_company_ids": tuple(
                    context.get("allowed_company_ids") or ()),
                "company_id": report_self.env.company.id,
            })
            return STUB_PDF, "pdf"

        IrActionsReport._render_qweb_pdf = spy
        self.addCleanup(setattr, IrActionsReport, "_render_qweb_pdf", original)
        return calls

    def test_list_payload_carries_an_authenticated_file_url(self):
        payslip = self._make_payslip()
        token = self._token()
        resp = self._get("/api/mobile/v1/payslip/list", token)
        self.assertEqual(resp.status_code, 200, resp.text)
        rows = resp.json()["data"]["payslips"]
        row = next(r for r in rows if r["id"] == payslip.id)

        self.assertIn("url", row)
        self.assertIn("/api/mobile/v1/payslip/%s/file" % payslip.id,
                      row["url"])
        self.assertEqual(row["download_url"], row["url"])
        self.assertTrue(row["download_requires_auth"])
        self.assertEqual(row["filename"], "Payslip_%s.pdf" % payslip.id)

    def test_both_paths_render_the_same_report_in_the_same_context(self):
        payslip = self._make_payslip()
        token = self._token()
        calls = self._capture_renders()

        resp = self._get("/api/mobile/v1/payslip/list", token)
        row = next(r for r in resp.json()["data"]["payslips"]
                   if r["id"] == payslip.id)

        direct = self._get(self._path_of(row["url"]), token)
        self.assertEqual(direct.status_code, 200, direct.text[:200])
        bearer = self._get(
            "/api/mobile/v1/payslip/%s/download" % payslip.id, token)
        self.assertEqual(bearer.status_code, 200, bearer.text[:200])

        self.assertEqual(len(calls), 2, "expected exactly one render per path")
        self.assertEqual(
            calls[0], calls[1],
            "the direct URL and legacy download path must render the same report for "
            "the same record in the same context, or they can produce "
            "different documents for one payslip")

        # And that context must be the payslip's own, not the caller's.
        # Same report the backend prints: the structure's report, else the generic payslip report.
        expected = payslip.sudo().struct_id.report_id or self.env.ref("hr_payroll.action_report_payslip")
        self.assertEqual(calls[0]["report_ref"], expected)
        self.assertEqual(calls[0]["res_ids"], [payslip.id])
        self.assertEqual(calls[0]["company_id"], payslip.company_id.id)
        self.assertEqual(calls[0]["allowed_company_ids"],
                         (payslip.company_id.id,))
        self.assertTrue(calls[0]["lang"], "language must be pinned, not inherited")

    def test_neither_path_alters_the_rendered_bytes(self):
        payslip = self._make_payslip()
        token = self._token()
        self._capture_renders()

        resp = self._get("/api/mobile/v1/payslip/list", token)
        row = next(r for r in resp.json()["data"]["payslips"]
                   if r["id"] == payslip.id)

        direct = self._get(self._path_of(row["url"]), token)
        self.assertEqual(direct.content, STUB_PDF,
                         "direct path must stream the renderer output verbatim")

        bearer = self._get(
            "/api/mobile/v1/payslip/%s/download" % payslip.id, token)
        self.assertEqual(
            bearer.content, STUB_PDF,
            "legacy download path must stream the renderer output verbatim")

    def test_direct_url_requires_bearer_and_serves_pdf_headers(self):
        payslip = self._make_payslip()
        token = self._token()
        self._capture_renders()
        resp = self._get("/api/mobile/v1/payslip/list", token)
        row = next(r for r in resp.json()["data"]["payslips"]
                   if r["id"] == payslip.id)

        unauthorised = self._get(self._path_of(row["url"]))
        self.assertEqual(unauthorised.status_code, 401)
        pdf = self._get(self._path_of(row["url"]), token)
        self.assertEqual(pdf.status_code, 200, pdf.text[:200])
        self.assertEqual(pdf.headers.get("Content-Type"), "application/pdf")
        self.assertIn("Payslip_%s.pdf" % payslip.id,
                      pdf.headers.get("Content-Disposition", ""))
        self.assertEqual(pdf.headers.get("Cache-Control"), "private, no-store")

    def test_direct_url_blocks_another_employees_payslip(self):
        mine = self._make_payslip()
        theirs = self._make_payslip(self.other_employee)
        token = self._token()
        resp = self._get("/api/mobile/v1/payslip/%s/file" % theirs.id, token)
        self.assertEqual(resp.status_code, 404)
        self.assertEqual(resp.json()["code"], "payslip_not_found")

    def test_legacy_download_path_returns_raw_pdf(self):
        payslip = self._make_payslip()
        token = self._token()
        self._capture_renders()
        resp = self._get(
            "/api/mobile/v1/payslip/%s/download" % payslip.id, token)
        self.assertEqual(resp.status_code, 200, resp.text[:200])
        self.assertEqual(resp.content, STUB_PDF)
        self.assertEqual(resp.headers.get("Content-Type"), "application/pdf")
        self.assertIn("Payslip_%s.pdf" % payslip.id,
                      resp.headers.get("Content-Disposition", ""))

    def test_legacy_download_path_still_blocks_another_employees_payslip(self):
        theirs = self._make_payslip(self.other_employee)
        token = self._token()
        resp = self._get(
            "/api/mobile/v1/payslip/%s/download" % theirs.id, token)
        self.assertEqual(resp.status_code, 404)
        self.assertEqual(resp.json()["code"], "payslip_not_found")
