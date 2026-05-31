from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import Select, desc, select
from sqlalchemy.orm import Session

from .config import Settings
from .models import (
    AccessTokenRecord,
    DeviceRecord,
    HealthMetricRecord,
    HealthWorkoutRecord,
    SyncBatchRecord,
    WorkspaceDeviceRecord,
    WorkspaceRecord,
)
from .schemas import (
    AgentCatalog,
    AgentDevice,
    HealthMetricOut,
    HealthWorkoutOut,
    HostedWorkspaceResponse,
    MetricDailySummary,
    MetricListResponse,
    PageInfo,
    SyncBatchListResponse,
    SyncBatchOut,
    SyncPayloadIn,
    UploadResult,
    WorkoutDailySummary,
    WorkoutListResponse,
)
from .tokens import generate_token, token_hash

SELF_HOSTED_WORKSPACE_ID = "self_hosted"


def provision_hosted_workspace(db: Session, settings: Settings, label: str | None) -> HostedWorkspaceResponse:
    created_at = datetime.now(timezone.utc)
    workspace_id = generate_token("wk")
    ingest_token = generate_token("hs_ingest")
    agent_token = generate_token("hs_agent")

    try:
        db.add(WorkspaceRecord(id=workspace_id, created_at=created_at, label=label))
        db.add_all(
            [
                AccessTokenRecord(
                    id=generate_token("tok"),
                    workspace_id=workspace_id,
                    kind="ingest",
                    token_hash=token_hash(ingest_token, settings.token_hash_secret),
                    created_at=created_at,
                ),
                AccessTokenRecord(
                    id=generate_token("tok"),
                    workspace_id=workspace_id,
                    kind="agent_read",
                    token_hash=token_hash(agent_token, settings.token_hash_secret),
                    created_at=created_at,
                ),
            ]
        )
        db.commit()
    except Exception:
        db.rollback()
        raise

    return HostedWorkspaceResponse(
        workspace_id=workspace_id,
        backend_url=settings.hosted_public_base_url,
        ingest_token=ingest_token,
        agent_endpoint=f"{settings.hosted_public_base_url}/api/agent/health-data",
        agent_token=agent_token,
    )


def persist_sync_payload(
    db: Session,
    payload: SyncPayloadIn,
    app_version: str | None,
    workspace_id: str,
) -> UploadResult:
    received_at = datetime.now(timezone.utc)
    export_id = str(payload.export_id)
    duplicates = 0

    try:
        ensure_workspace(db, workspace_id, received_at)

        device = db.get(DeviceRecord, payload.device_id)
        if device is None:
            db.add(
                DeviceRecord(
                    device_id=payload.device_id,
                    first_seen_at=received_at,
                    last_seen_at=received_at,
                    app_version=app_version,
                )
            )
        else:
            device.last_seen_at = received_at
            device.app_version = app_version or device.app_version

        workspace_device = db.get(WorkspaceDeviceRecord, (workspace_id, payload.device_id))
        if workspace_device is None:
            db.add(
                WorkspaceDeviceRecord(
                    workspace_id=workspace_id,
                    device_id=payload.device_id,
                    created_at=received_at,
                    last_seen_at=received_at,
                )
            )
        else:
            workspace_device.last_seen_at = received_at

        batch = db.get(SyncBatchRecord, (workspace_id, export_id))
        if batch is None:
            db.add(
                SyncBatchRecord(
                    export_id=export_id,
                    workspace_id=workspace_id,
                    device_id=payload.device_id,
                    generated_at=payload.generated_at,
                    received_at=received_at,
                    schema_version=payload.schema_version,
                    timezone=payload.timezone,
                    source=payload.source,
                    date_range_start=payload.date_range.start,
                    date_range_end=payload.date_range.end,
                    metrics_count=len(payload.metrics),
                    workouts_count=len(payload.workouts),
                )
            )
        else:
            batch.received_at = received_at
            batch.metrics_count = len(payload.metrics)
            batch.workouts_count = len(payload.workouts)

        for metric in payload.metrics:
            record = db.get(HealthMetricRecord, (workspace_id, payload.device_id, metric.id))
            if record is None:
                db.add(
                    HealthMetricRecord(
                        workspace_id=workspace_id,
                        device_id=payload.device_id,
                        id=metric.id,
                        type=metric.type,
                        value=metric.value,
                        unit=metric.unit,
                        start_at=metric.start_at,
                        end_at=metric.end_at,
                        source_name=metric.source_name,
                        source_bundle_id=metric.source_bundle_id,
                        metadata_json=dict(metric.metadata),
                        export_id=export_id,
                    )
                )
            else:
                duplicates += 1
                record.type = metric.type
                record.value = metric.value
                record.unit = metric.unit
                record.start_at = metric.start_at
                record.end_at = metric.end_at
                record.source_name = metric.source_name
                record.source_bundle_id = metric.source_bundle_id
                record.metadata_json = dict(metric.metadata)
                record.export_id = export_id

        for workout in payload.workouts:
            record = db.get(HealthWorkoutRecord, (workspace_id, payload.device_id, workout.id))
            if record is None:
                db.add(
                    HealthWorkoutRecord(
                        workspace_id=workspace_id,
                        device_id=payload.device_id,
                        id=workout.id,
                        activity_type=workout.activity_type,
                        start_at=workout.start_at,
                        end_at=workout.end_at,
                        duration_seconds=workout.duration_seconds,
                        total_energy_kcal=workout.total_energy_kcal,
                        active_energy_kcal=workout.active_energy_kcal,
                        distance_meters=workout.distance_meters,
                        source_name=workout.source_name,
                        source_bundle_id=workout.source_bundle_id,
                        metadata_json=dict(workout.metadata),
                        export_id=export_id,
                    )
                )
            else:
                duplicates += 1
                record.activity_type = workout.activity_type
                record.start_at = workout.start_at
                record.end_at = workout.end_at
                record.duration_seconds = workout.duration_seconds
                record.total_energy_kcal = workout.total_energy_kcal
                record.active_energy_kcal = workout.active_energy_kcal
                record.distance_meters = workout.distance_meters
                record.source_name = workout.source_name
                record.source_bundle_id = workout.source_bundle_id
                record.metadata_json = dict(workout.metadata)
                record.export_id = export_id

        db.commit()
    except Exception:
        db.rollback()
        raise

    return UploadResult(ok=True, received=len(payload.metrics) + len(payload.workouts), duplicates=duplicates)


def list_metrics(
    db: Session,
    *,
    workspace_id: str | None = None,
    device_id: str | None = None,
    metric_type: str | None = None,
    start_at: datetime | None = None,
    end_at: datetime | None = None,
    limit: int = 100,
    offset: int = 0,
) -> MetricListResponse:
    stmt: Select[tuple[HealthMetricRecord]] = select(HealthMetricRecord)
    if workspace_id:
        stmt = stmt.where(HealthMetricRecord.workspace_id == workspace_id)
    if device_id:
        stmt = stmt.where(HealthMetricRecord.device_id == device_id)
    if metric_type:
        stmt = stmt.where(HealthMetricRecord.type == metric_type)
    if start_at:
        stmt = stmt.where(HealthMetricRecord.start_at >= start_at)
    if end_at:
        stmt = stmt.where(HealthMetricRecord.end_at <= end_at)

    records = db.scalars(stmt.order_by(desc(HealthMetricRecord.start_at)).limit(limit + 1).offset(offset)).all()
    has_more = len(records) > limit
    page_records = records[:limit]
    timezone_lookup = load_batch_timezones(db, page_records)
    return MetricListResponse(
        items=[metric_record_to_schema(record, timezone_lookup) for record in page_records],
        page=PageInfo(limit=limit, offset=offset, has_more=has_more),
    )


def list_workouts(
    db: Session,
    *,
    workspace_id: str | None = None,
    device_id: str | None = None,
    activity_type: str | None = None,
    start_at: datetime | None = None,
    end_at: datetime | None = None,
    limit: int = 100,
    offset: int = 0,
) -> WorkoutListResponse:
    stmt: Select[tuple[HealthWorkoutRecord]] = select(HealthWorkoutRecord)
    if workspace_id:
        stmt = stmt.where(HealthWorkoutRecord.workspace_id == workspace_id)
    if device_id:
        stmt = stmt.where(HealthWorkoutRecord.device_id == device_id)
    if activity_type:
        stmt = stmt.where(HealthWorkoutRecord.activity_type == activity_type)
    if start_at:
        stmt = stmt.where(HealthWorkoutRecord.start_at >= start_at)
    if end_at:
        stmt = stmt.where(HealthWorkoutRecord.end_at <= end_at)

    records = db.scalars(stmt.order_by(desc(HealthWorkoutRecord.start_at)).limit(limit + 1).offset(offset)).all()
    has_more = len(records) > limit
    page_records = records[:limit]
    timezone_lookup = load_batch_timezones(db, page_records)
    return WorkoutListResponse(
        items=[workout_record_to_schema(record, timezone_lookup) for record in page_records],
        page=PageInfo(limit=limit, offset=offset, has_more=has_more),
    )


def list_sync_batches(
    db: Session,
    *,
    workspace_id: str | None = None,
    device_id: str | None = None,
    start_at: datetime | None = None,
    end_at: datetime | None = None,
    limit: int = 100,
    offset: int = 0,
) -> SyncBatchListResponse:
    stmt: Select[tuple[SyncBatchRecord]] = select(SyncBatchRecord)
    if workspace_id:
        stmt = stmt.where(SyncBatchRecord.workspace_id == workspace_id)
    if device_id:
        stmt = stmt.where(SyncBatchRecord.device_id == device_id)
    if start_at:
        stmt = stmt.where(SyncBatchRecord.date_range_end >= start_at)
    if end_at:
        stmt = stmt.where(SyncBatchRecord.date_range_start <= end_at)

    records = db.scalars(stmt.order_by(desc(SyncBatchRecord.received_at)).limit(limit + 1).offset(offset)).all()
    has_more = len(records) > limit
    page_records = records[:limit]
    return SyncBatchListResponse(
        items=[sync_batch_record_to_schema(record) for record in page_records],
        page=PageInfo(limit=limit, offset=offset, has_more=has_more),
    )


def ensure_workspace(db: Session, workspace_id: str, created_at: datetime) -> None:
    if db.get(WorkspaceRecord, workspace_id) is None:
        db.add(WorkspaceRecord(id=workspace_id, created_at=created_at, label=None))


def get_agent_catalog(db: Session, workspace_id: str) -> AgentCatalog:
    metric_types = db.scalars(
        select(HealthMetricRecord.type)
        .where(HealthMetricRecord.workspace_id == workspace_id)
        .distinct()
        .order_by(HealthMetricRecord.type)
    ).all()
    activity_types = db.scalars(
        select(HealthWorkoutRecord.activity_type)
        .where(HealthWorkoutRecord.workspace_id == workspace_id)
        .distinct()
        .order_by(HealthWorkoutRecord.activity_type)
    ).all()
    timezones = db.scalars(
        select(SyncBatchRecord.timezone)
        .where(SyncBatchRecord.workspace_id == workspace_id)
        .distinct()
        .order_by(SyncBatchRecord.timezone)
    ).all()
    devices = db.scalars(
        select(WorkspaceDeviceRecord)
        .where(WorkspaceDeviceRecord.workspace_id == workspace_id)
        .order_by(WorkspaceDeviceRecord.device_id)
    ).all()
    return AgentCatalog(
        metric_types=list(metric_types),
        activity_types=list(activity_types),
        timezones=list(timezones),
        devices=[AgentDevice(device_id=device.device_id, label=device.label) for device in devices],
    )


def summarize_metric_items(items: list[HealthMetricOut]) -> list[MetricDailySummary]:
    grouped: dict[tuple[str, str, str], list[float]] = defaultdict(list)
    for item in items:
        grouped[(item.local_date, item.type, item.unit)].append(item.value)

    summaries = []
    for (local_date, metric_type, unit), values in sorted(grouped.items()):
        total = sum(values)
        summaries.append(
            MetricDailySummary(
                local_date=local_date,
                type=metric_type,
                unit=unit,
                sample_count=len(values),
                total_value=total,
                average_value=total / len(values),
                minimum_value=min(values),
                maximum_value=max(values),
            )
        )
    return summaries


def summarize_workout_items(items: list[HealthWorkoutOut]) -> list[WorkoutDailySummary]:
    grouped: dict[tuple[str, str], list[HealthWorkoutOut]] = defaultdict(list)
    for item in items:
        grouped[(item.local_date, item.activity_type)].append(item)

    summaries = []
    for (local_date, activity_type), workouts in sorted(grouped.items()):
        distance_values = [workout.distance_meters for workout in workouts if workout.distance_meters is not None]
        total_energy_values = [workout.total_energy_kcal for workout in workouts if workout.total_energy_kcal is not None]
        active_energy_values = [workout.active_energy_kcal for workout in workouts if workout.active_energy_kcal is not None]
        summaries.append(
            WorkoutDailySummary(
                local_date=local_date,
                activity_type=activity_type,
                workout_count=len(workouts),
                duration_minutes=sum(workout.duration_seconds for workout in workouts) / 60,
                distance_km=sum(distance_values) / 1000 if distance_values else None,
                total_energy_kcal=sum(total_energy_values) if total_energy_values else None,
                active_energy_kcal=sum(active_energy_values) if active_energy_values else None,
            )
        )
    return summaries


def load_batch_timezones(
    db: Session,
    records: list[HealthMetricRecord] | list[HealthWorkoutRecord],
) -> dict[tuple[str, str], str]:
    keys = {(record.workspace_id, record.export_id) for record in records}
    if not keys:
        return {}
    workspace_ids = {workspace_id for workspace_id, _ in keys}
    export_ids = {export_id for _, export_id in keys}
    rows = db.execute(
        select(SyncBatchRecord.workspace_id, SyncBatchRecord.export_id, SyncBatchRecord.timezone).where(
            SyncBatchRecord.workspace_id.in_(workspace_ids),
            SyncBatchRecord.export_id.in_(export_ids),
        )
    ).all()
    return {(workspace_id, export_id): batch_timezone for workspace_id, export_id, batch_timezone in rows}


def metric_record_to_schema(
    record: HealthMetricRecord,
    timezone_lookup: dict[tuple[str, str], str],
) -> HealthMetricOut:
    batch_timezone = timezone_lookup.get((record.workspace_id, record.export_id), "UTC")
    return HealthMetricOut(
        id=record.id,
        device_id=record.device_id,
        type=record.type,
        value=record.value,
        unit=record.unit,
        start_at=record.start_at,
        end_at=record.end_at,
        timezone=batch_timezone,
        local_date=local_date_for(record.start_at, batch_timezone),
        source_name=record.source_name,
        source_bundle_id=record.source_bundle_id,
        metadata=record.metadata_json or {},
        export_id=record.export_id,
    )


def workout_record_to_schema(
    record: HealthWorkoutRecord,
    timezone_lookup: dict[tuple[str, str], str],
) -> HealthWorkoutOut:
    batch_timezone = timezone_lookup.get((record.workspace_id, record.export_id), "UTC")
    return HealthWorkoutOut(
        id=record.id,
        device_id=record.device_id,
        activity_type=record.activity_type,
        start_at=record.start_at,
        end_at=record.end_at,
        timezone=batch_timezone,
        local_date=local_date_for(record.start_at, batch_timezone),
        duration_seconds=record.duration_seconds,
        total_energy_kcal=record.total_energy_kcal,
        active_energy_kcal=record.active_energy_kcal,
        distance_meters=record.distance_meters,
        source_name=record.source_name,
        source_bundle_id=record.source_bundle_id,
        metadata=record.metadata_json or {},
        export_id=record.export_id,
    )


def sync_batch_record_to_schema(record: SyncBatchRecord) -> SyncBatchOut:
    return SyncBatchOut(
        export_id=record.export_id,
        device_id=record.device_id,
        generated_at=record.generated_at,
        received_at=record.received_at,
        schema_version=record.schema_version,
        timezone=record.timezone,
        source=record.source,
        date_range_start=record.date_range_start,
        date_range_end=record.date_range_end,
        metrics_count=record.metrics_count,
        workouts_count=record.workouts_count,
    )


def local_date_for(timestamp: datetime, batch_timezone: str) -> str:
    timestamp = timestamp if timestamp.tzinfo is not None else timestamp.replace(tzinfo=timezone.utc)
    try:
        local_timezone = ZoneInfo(batch_timezone)
    except ZoneInfoNotFoundError:
        local_timezone = timezone.utc
    return timestamp.astimezone(local_timezone).date().isoformat()
