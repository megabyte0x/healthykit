from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    database_url: str
    api_token: str
    token_hash_secret: str
    hosted_public_base_url: str
    hosted_provisioning_enabled: bool = False
    self_hosted_workspace_id: str = "self_hosted"
    default_page_size: int = 100
    max_page_size: int = 500

    @classmethod
    def from_env(cls) -> "Settings":
        database_url = os.environ.get("DATABASE_URL", "").strip()
        api_token = os.environ.get("API_TOKEN", "").strip()
        token_hash_secret = os.environ.get("TOKEN_HASH_SECRET", "").strip()
        hosted_provisioning_enabled = _env_bool(os.environ.get("HOSTED_PROVISIONING_ENABLED"))
        hosted_public_base_url = os.environ.get("HOSTED_PUBLIC_BASE_URL", "").strip().rstrip("/")
        if not database_url:
            raise RuntimeError("DATABASE_URL is required.")
        if not api_token:
            raise RuntimeError("API_TOKEN is required.")
        if not token_hash_secret:
            raise RuntimeError("TOKEN_HASH_SECRET is required.")
        if hosted_provisioning_enabled and not hosted_public_base_url:
            raise RuntimeError("HOSTED_PUBLIC_BASE_URL is required when hosted provisioning is enabled.")
        return cls(
            database_url=database_url,
            api_token=api_token,
            token_hash_secret=token_hash_secret,
            hosted_public_base_url=hosted_public_base_url,
            hosted_provisioning_enabled=hosted_provisioning_enabled,
        )


def _env_bool(value: str | None) -> bool:
    return (value or "").strip().lower() in {"1", "true", "yes", "on"}
