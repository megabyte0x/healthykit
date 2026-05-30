from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import secrets

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import Settings
from .models import AccessTokenRecord
from .tokens import token_hash


@dataclass(frozen=True)
class AuthContext:
    workspace_id: str
    token_kind: str
    self_hosted: bool = False


def bearer_token(authorization: str | None) -> str:
    if authorization is None or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    token = authorization.removeprefix("Bearer ").strip()
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    return token


def resolve_sync_auth(db: Session, settings: Settings, authorization: str | None) -> AuthContext:
    token = bearer_token(authorization)
    if secrets.compare_digest(token.encode("utf-8"), settings.api_token.encode("utf-8")):
        return AuthContext(
            workspace_id=settings.self_hosted_workspace_id,
            token_kind="self_hosted",
            self_hosted=True,
        )
    return resolve_access_token(db, settings, token, expected_kind="ingest")


def resolve_agent_auth(db: Session, settings: Settings, authorization: str | None) -> AuthContext:
    token = bearer_token(authorization)
    return resolve_access_token(db, settings, token, expected_kind="agent_read")


def resolve_access_token(
    db: Session,
    settings: Settings,
    token: str,
    *,
    expected_kind: str,
) -> AuthContext:
    candidate_hash = token_hash(token, settings.token_hash_secret)
    record = db.scalar(select(AccessTokenRecord).where(AccessTokenRecord.token_hash == candidate_hash))
    if record is None or record.revoked_at is not None or record.kind != expected_kind:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid bearer token")

    record.last_used_at = datetime.now(timezone.utc)
    db.commit()
    return AuthContext(workspace_id=record.workspace_id, token_kind=record.kind)
