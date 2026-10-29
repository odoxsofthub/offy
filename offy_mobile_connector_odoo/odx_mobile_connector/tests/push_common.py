import base64
import json

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa


def make_service_account(overrides=None, drop=None):
    """Return a valid service-account dict with a real RSA key for offline JWT signing.
    `overrides` merges keys; `drop` removes keys."""
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pem = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.TraditionalOpenSSL,
        serialization.NoEncryption(),
    ).decode("utf-8")
    data = {
        "type": "service_account",
        "project_id": "test-project",
        "private_key_id": "test-key-id",
        "private_key": pem,
        "client_email": "svc@test-project.iam.gserviceaccount.com",
        "token_uri": "https://oauth2.googleapis.com/token",
    }
    if overrides:
        data.update(overrides)
    for key_name in drop or ():
        data.pop(key_name, None)
    return data


def encode_service_account(data):
    """Base64-encode a dict as Odoo stores a Binary field value."""
    return base64.b64encode(json.dumps(data).encode("utf-8"))
