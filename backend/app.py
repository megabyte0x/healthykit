from __future__ import annotations

from collections.abc import Generator
from datetime import datetime
import secrets
from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException, Query, status
from sqlalchemy.orm import Session, sessionmaker

from .config import Settings
from .database import create_engine_for_url, create_session_factory
from .repository import list_metrics, list_sync_batches, list_workouts, persist_sync_payload
from .schemas import MetricListResponse, SyncBatchListResponse, SyncPayloadIn, UploadResult, WorkoutListResponse


def create_app(
    settings: Settings | None = None,
    *,
    session_factory: sessionmaker[Session] | None = None,
) -> FastAPI:
    settings = settings or Settings.from_env()
    if session_factory is None:
        engine = create_engine_for_url(settings.database_url)
        session_factory = create_session_factory(engine)

    app = FastAPI(title="HealthSync Backend", version="1.0.0")

    def require_token(authorization: Annotated[str | None, Header()] = None) -> None:
        if authorization is None or not authorization.startswith("Bearer "):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
        token = authorization.removeprefix("Bearer ").strip()
        if not secrets.compare_digest(token.encode("utf-8"), settings.api_token.encode("utf-8")):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid bearer token")

    def get_db() -> Generator[Session]:
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    @app.get("/health")
    def health() -> dict[str, bool]:
        return {"ok": True}

    @app.post("/api/apple-health/sync", response_model=UploadResult)
    def apple_health_sync(
        payload: SyncPayloadIn,
        _: None = Depends(require_token),
        db: Session = Depends(get_db),
        x_app_version: Annotated[str | None, Header(alias="X-App-Version")] = None,
    ) -> UploadResult:
        return persist_sync_payload(db, payload, x_app_version)

    @app.get("/api/apple-health/metrics", response_model=MetricListResponse)
    def apple_health_metrics(
        _: None = Depends(require_token),
        db: Session = Depends(get_db),
        device_id: str | None = None,
        metric_type: str | None = Query(default=None, alias="type"),
        start_at: datetime | None = None,
        end_at: datetime | None = None,
        limit: int = Query(default=settings.default_page_size, ge=1, le=settings.max_page_size),
        offset: int = Query(default=0, ge=0),
    ) -> MetricListResponse:
        return list_metrics(
            db,
            device_id=device_id,
            metric_type=metric_type,
            start_at=start_at,
            end_at=end_at,
            limit=limit,
            offset=offset,
        )

    @app.get("/api/apple-health/workouts", response_model=WorkoutListResponse)
    def apple_health_workouts(
        _: None = Depends(require_token),
        db: Session = Depends(get_db),
        device_id: str | None = None,
        activity_type: str | None = None,
        start_at: datetime | None = None,
        end_at: datetime | None = None,
        limit: int = Query(default=settings.default_page_size, ge=1, le=settings.max_page_size),
        offset: int = Query(default=0, ge=0),
    ) -> WorkoutListResponse:
        return list_workouts(
            db,
            device_id=device_id,
            activity_type=activity_type,
            start_at=start_at,
            end_at=end_at,
            limit=limit,
            offset=offset,
        )

    @app.get("/api/apple-health/syncs", response_model=SyncBatchListResponse)
    def apple_health_syncs(
        _: None = Depends(require_token),
        db: Session = Depends(get_db),
        device_id: str | None = None,
        limit: int = Query(default=settings.default_page_size, ge=1, le=settings.max_page_size),
        offset: int = Query(default=0, ge=0),
    ) -> SyncBatchListResponse:
        return list_sync_batches(db, device_id=device_id, limit=limit, offset=offset)

    return app
