from __future__ import annotations

import hashlib
import hmac
import secrets


def generate_token(prefix: str) -> str:
    return f"{prefix}_{secrets.token_urlsafe(32)}"


def token_hash(token: str, secret: str) -> str:
    return hmac.new(secret.encode("utf-8"), token.encode("utf-8"), hashlib.sha256).hexdigest()


def token_hash_matches(token: str, stored_hash: str, secret: str) -> bool:
    candidate = token_hash(token, secret)
    return hmac.compare_digest(candidate.encode("utf-8"), stored_hash.encode("utf-8"))
