from __future__ import annotations

from collections.abc import Generator
from datetime import datetime
import secrets
from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException, Query, status
from sqlalchemy.orm import Session, sessionmaker

from .auth import AuthContext, bearer_token, resolve_agent_auth, resolve_sync_auth
from .config import Settings
from .database import create_engine_for_url, create_session_factory
from .repository import (
    get_agent_catalog,
    list_metric_summary_items,
    list_metrics,
    list_sync_batches,
    list_workout_summary_items,
    list_workouts,
    persist_sync_payload,
    provision_hosted_workspace,
    reset_hosted_workspace,
    rotate_hosted_agent_token,
    summarize_metric_items,
    summarize_workout_items,
)
from .schemas import (
    AgentHealthDataResponse,
    AgentRange,
    HostedAgentTokenResponse,
    HostedWorkspaceCreate,
    HostedWorkspaceResponse,
    MetricListResponse,
    SyncBatchListResponse,
    SyncPayloadIn,
    UploadResult,
    WorkoutListResponse,
)


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

    def require_self_hosted_auth(authorization: Annotated[str | None, Header()] = None) -> AuthContext:
        token = bearer_token(authorization)
        if not secrets.compare_digest(token.encode("utf-8"), settings.api_token.encode("utf-8")):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid bearer token")
        return AuthContext(
            workspace_id=settings.self_hosted_workspace_id,
            token_kind="self_hosted",
            self_hosted=True,
        )

    def get_db() -> Generator[Session]:
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    def require_sync_auth(
        authorization: Annotated[str | None, Header()] = None,
        db: Session = Depends(get_db),
    ) -> AuthContext:
        return resolve_sync_auth(db, settings, authorization)

    def require_agent_auth(
        authorization: Annotated[str | None, Header()] = None,
        db: Session = Depends(get_db),
    ) -> AuthContext:
        return resolve_agent_auth(db, settings, authorization)

    @app.get("/health")
    def health() -> dict[str, bool]:
        return {"ok": True}

    @app.post("/api/hosted/workspaces", response_model=HostedWorkspaceResponse)
    def hosted_workspaces(
        payload: HostedWorkspaceCreate,
        db: Session = Depends(get_db),
    ) -> HostedWorkspaceResponse:
        if not settings.hosted_provisioning_enabled:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
        return provision_hosted_workspace(db, settings, payload.label)

    @app.post("/api/hosted/workspaces/reset", response_model=HostedWorkspaceResponse)
    def hosted_workspaces_reset(
        payload: HostedWorkspaceCreate,
        auth: AuthContext = Depends(require_sync_auth),
        db: Session = Depends(get_db),
    ) -> HostedWorkspaceResponse:
        if not settings.hosted_provisioning_enabled or auth.self_hosted:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid bearer token")
        return reset_hosted_workspace(db, settings, auth.workspace_id, payload.label)

    @app.post("/api/hosted/agent-token", response_model=HostedAgentTokenResponse)
    def hosted_agent_token(
        auth: AuthContext = Depends(require_sync_auth),
        db: Session = Depends(get_db),
    ) -> HostedAgentTokenResponse:
        if not settings.hosted_provisioning_enabled or auth.self_hosted:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid bearer token")
        return rotate_hosted_agent_token(db, settings, auth.workspace_id)

    @app.post("/api/apple-health/sync", response_model=UploadResult)
    def apple_health_sync(
        payload: SyncPayloadIn,
        auth: AuthContext = Depends(require_sync_auth),
        db: Session = Depends(get_db),
        x_app_version: Annotated[str | None, Header(alias="X-App-Version")] = None,
    ) -> UploadResult:
        return persist_sync_payload(db, payload, x_app_version, auth.workspace_id)

    @app.get("/api/apple-health/metrics", response_model=MetricListResponse)
    def apple_health_metrics(
        auth: AuthContext = Depends(require_self_hosted_auth),
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
            workspace_id=auth.workspace_id,
            device_id=device_id,
            metric_type=metric_type,
            start_at=start_at,
            end_at=end_at,
            limit=limit,
            offset=offset,
        )

    @app.get("/api/apple-health/workouts", response_model=WorkoutListResponse)
    def apple_health_workouts(
        auth: AuthContext = Depends(require_self_hosted_auth),
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
            workspace_id=auth.workspace_id,
            device_id=device_id,
            activity_type=activity_type,
            start_at=start_at,
            end_at=end_at,
            limit=limit,
            offset=offset,
        )

    @app.get("/api/apple-health/syncs", response_model=SyncBatchListResponse)
    def apple_health_syncs(
        auth: AuthContext = Depends(require_self_hosted_auth),
        db: Session = Depends(get_db),
        device_id: str | None = None,
        limit: int = Query(default=settings.default_page_size, ge=1, le=settings.max_page_size),
        offset: int = Query(default=0, ge=0),
    ) -> SyncBatchListResponse:
        return list_sync_batches(db, workspace_id=auth.workspace_id, device_id=device_id, limit=limit, offset=offset)

    @app.get("/api/agent/metrics", response_model=MetricListResponse)
    def agent_metrics(
        auth: AuthContext = Depends(require_agent_auth),
        db: Session = Depends(get_db),
        metric_type: str | None = Query(default=None, alias="type"),
        from_at: datetime | None = Query(default=None, alias="from"),
        to: datetime | None = None,
        limit: int = Query(default=settings.default_page_size, ge=1, le=settings.max_page_size),
        offset: int = Query(default=0, ge=0),
    ) -> MetricListResponse:
        return list_metrics(
            db,
            workspace_id=auth.workspace_id,
            metric_type=metric_type,
            start_at=from_at,
            end_at=to,
            limit=limit,
            offset=offset,
        )

    @app.get("/api/agent/workouts", response_model=WorkoutListResponse)
    def agent_workouts(
        auth: AuthContext = Depends(require_agent_auth),
        db: Session = Depends(get_db),
        activity_type: str | None = None,
        from_at: datetime | None = Query(default=None, alias="from"),
        to: datetime | None = None,
        limit: int = Query(default=settings.default_page_size, ge=1, le=settings.max_page_size),
        offset: int = Query(default=0, ge=0),
    ) -> WorkoutListResponse:
        return list_workouts(
            db,
            workspace_id=auth.workspace_id,
            activity_type=activity_type,
            start_at=from_at,
            end_at=to,
            limit=limit,
            offset=offset,
        )

    @app.get("/api/agent/syncs", response_model=SyncBatchListResponse)
    def agent_syncs(
        auth: AuthContext = Depends(require_agent_auth),
        db: Session = Depends(get_db),
        device_id: str | None = None,
        limit: int = Query(default=settings.default_page_size, ge=1, le=settings.max_page_size),
        offset: int = Query(default=0, ge=0),
    ) -> SyncBatchListResponse:
        return list_sync_batches(db, workspace_id=auth.workspace_id, device_id=device_id, limit=limit, offset=offset)

    @app.get("/api/agent/health-data", response_model=AgentHealthDataResponse)
    def agent_health_data(
        auth: AuthContext = Depends(require_agent_auth),
        db: Session = Depends(get_db),
        metric_type: str | None = Query(default=None, alias="type"),
        from_at: datetime | None = Query(default=None, alias="from"),
        to: datetime | None = None,
        limit: int = Query(default=settings.default_page_size, ge=1, le=settings.max_page_size),
        offset: int = Query(default=0, ge=0),
    ) -> AgentHealthDataResponse:
        metrics = list_metrics(
            db,
            workspace_id=auth.workspace_id,
            metric_type=metric_type,
            start_at=from_at,
            end_at=to,
            limit=limit,
            offset=offset,
        )
        workouts = list_workouts(
            db,
            workspace_id=auth.workspace_id,
            start_at=from_at,
            end_at=to,
            limit=limit,
            offset=offset,
        )
        syncs = list_sync_batches(
            db,
            workspace_id=auth.workspace_id,
            start_at=from_at,
            end_at=to,
            limit=limit,
            offset=offset,
        )
        metric_summary_items = list_metric_summary_items(
            db,
            workspace_id=auth.workspace_id,
            metric_type=metric_type,
            start_at=from_at,
            end_at=to,
        )
        workout_summary_items = list_workout_summary_items(
            db,
            workspace_id=auth.workspace_id,
            start_at=from_at,
            end_at=to,
        )
        return AgentHealthDataResponse(
            agent_schema_version=2,
            workspace_id=auth.workspace_id,
            range=AgentRange(from_at=from_at, to=to),
            page=metrics.page.model_copy(update={"has_more": metrics.page.has_more or workouts.page.has_more or syncs.page.has_more}),
            catalog=get_agent_catalog(db, auth.workspace_id),
            metrics=metrics.items,
            workouts=workouts.items,
            syncs=syncs.items,
            metric_daily_summaries=summarize_metric_items(metric_summary_items),
            workout_daily_summaries=summarize_workout_items(workout_summary_items),
        )

    return app
