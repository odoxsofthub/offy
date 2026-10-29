"""Content-based upload validation: the extension decides what is allowed, magic bytes confirm it.
Client Content-Type is never trusted; `guess_mimetype` is avoided (None for HEIC, tracebacks on fake ZIPs)."""

# Server-derived mimetype: the client's declared type never reaches the database.
ALLOWED_UPLOAD_EXTENSIONS = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".heic": "image/heic",
    ".pdf": "application/pdf",
    ".doc": "application/msword",
    ".docx": ("application/vnd.openxmlformats-officedocument"
              ".wordprocessingml.document"),
    ".xls": "application/vnd.ms-excel",
    ".xlsx": ("application/vnd.openxmlformats-officedocument"
              ".spreadsheetml.sheet"),
}

# ISO base-media brands that identify a HEIC/HEIF still image.
_HEIF_BRANDS = {b"heic", b"heix", b"hevc", b"hevx", b"heim", b"heis",
                b"hevm", b"hevs", b"mif1", b"msf1", b"heif"}

# OOXML is a ZIP and legacy .doc/.xls are OLE2; the signature confirms only the family.
_ZIP_SIGNATURES = (b"PK\x03\x04", b"PK\x05\x06", b"PK\x07\x08")
_OLE2_SIGNATURE = b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"


def _is_jpeg(content):
    return content.startswith(b"\xff\xd8\xff")


def _is_png(content):
    return content.startswith(b"\x89PNG\r\n\x1a\n")


def _is_webp(content):
    return (len(content) >= 12 and content[:4] == b"RIFF"
            and content[8:12] == b"WEBP")


def _is_heif(content):
    return (len(content) >= 12 and content[4:8] == b"ftyp"
            and content[8:12] in _HEIF_BRANDS)


def _is_pdf(content):
    # Acrobat tolerates leading junk before %PDF-, so look in the first 1024 bytes.
    return b"%PDF-" in content[:1024]


def _is_zip(content):
    return content.startswith(_ZIP_SIGNATURES)


def _is_ole2(content):
    return content.startswith(_OLE2_SIGNATURE)


# extension -> the predicate its bytes must satisfy.
_SIGNATURE_CHECKS = {
    ".jpg": _is_jpeg,
    ".jpeg": _is_jpeg,
    ".png": _is_png,
    ".webp": _is_webp,
    ".heic": _is_heif,
    ".pdf": _is_pdf,
    ".doc": _is_ole2,
    ".docx": _is_zip,
    ".xls": _is_ole2,
    ".xlsx": _is_zip,
}

ALLOWED_UPLOAD_LABEL = "JPG, PNG, WEBP, HEIC, PDF, DOC, DOCX, XLS or XLSX"


def upload_extension(filename):
    """The allowlisted extension of *filename*, or None."""
    lowered = (filename or "").strip().lower()
    for extension in ALLOWED_UPLOAD_EXTENSIONS:
        if lowered.endswith(extension):
            return extension
    return None


def resolve_upload_mimetype(filename):
    """Server-derived mimetype for *filename*, or None if not allowed."""
    extension = upload_extension(filename)
    return ALLOWED_UPLOAD_EXTENSIONS.get(extension)


def validate_upload(filename, content):
    """Check *content* is really the type *filename* claims; return ``(mimetype, None)`` or ``(None, message)``.
    The message never names the detected type, so the guard is not a probing oracle."""
    extension = upload_extension(filename)
    if not extension:
        return None, ("Unsupported file type. Allowed formats: %s."
                      % ALLOWED_UPLOAD_LABEL)
    if not _SIGNATURE_CHECKS[extension](content or b""):
        return None, ("The file contents do not match its %s extension."
                      % extension)
    return ALLOWED_UPLOAD_EXTENSIONS[extension], None
