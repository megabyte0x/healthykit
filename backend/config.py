from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    database_url: str
    api_token: str
    default_page_size: int = 100
    max_page_size: int = 500

    @classmethod
    def from_env(cls) -> "Settings":
        database_url = os.environ.get("DATABASE_URL", "").strip()
        api_token = os.environ.get("API_TOKEN", "").strip()
        if not database_url:
            raise RuntimeError("DATABASE_URL is required.")
        if not api_token:
            raise RuntimeError("API_TOKEN is required.")
        return cls(database_url=database_url, api_token=api_token)
