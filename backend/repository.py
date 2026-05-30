from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import Select, desc, select
from sqlalchemy.orm import Session

from .models import DeviceRecord, HealthMetricRecord, HealthWorkoutRecord, SyncBatchRecord
from .schemas import (
    HealthMetricOut,
    HealthWorkoutOut,
    MetricListResponse,
    SyncBatchListResponse,
    SyncBatchOut,
    SyncPayloadIn,
    UploadResult,
    WorkoutListResponse,
)


def persist_sync_payload(db: Session, payload: SyncPayloadIn, app_version: str | None) -> UploadResult:
    received_at = datetime.now(timezone.utc)
    export_id = str(payload.export_id)
    duplicates = 0

    try:
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

        batch = db.get(SyncBatchRecord, export_id)
        if batch is None:
            db.add(
                SyncBatchRecord(
                    export_id=export_id,
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
            record = db.get(HealthMetricRecord, (payload.device_id, metric.id))
            if record is None:
                db.add(
                    HealthMetricRecord(
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
            record = db.get(HealthWorkoutRecord, (payload.device_id, workout.id))
            if record is None:
                db.add(
                    HealthWorkoutRecord(
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
    device_id: str | None = None,
    metric_type: str | None = None,
    start_at: datetime | None = None,
    end_at: datetime | None = None,
    limit: int = 100,
    offset: int = 0,
) -> MetricListResponse:
    stmt: Select[tuple[HealthMetricRecord]] = select(HealthMetricRecord)
    if device_id:
        stmt = stmt.where(HealthMetricRecord.device_id == device_id)
    if metric_type:
        stmt = stmt.where(HealthMetricRecord.type == metric_type)
    if start_at:
        stmt = stmt.where(HealthMetricRecord.start_at >= start_at)
    if end_at:
        stmt = stmt.where(HealthMetricRecord.end_at <= end_at)

    records = db.scalars(stmt.order_by(desc(HealthMetricRecord.start_at)).limit(limit).offset(offset)).all()
    return MetricListResponse(items=[metric_record_to_schema(record) for record in records])


def list_workouts(
    db: Session,
    *,
    device_id: str | None = None,
    activity_type: str | None = None,
    start_at: datetime | None = None,
    end_at: datetime | None = None,
    limit: int = 100,
    offset: int = 0,
) -> WorkoutListResponse:
    stmt: Select[tuple[HealthWorkoutRecord]] = select(HealthWorkoutRecord)
    if device_id:
        stmt = stmt.where(HealthWorkoutRecord.device_id == device_id)
    if activity_type:
        stmt = stmt.where(HealthWorkoutRecord.activity_type == activity_type)
    if start_at:
        stmt = stmt.where(HealthWorkoutRecord.start_at >= start_at)
    if end_at:
        stmt = stmt.where(HealthWorkoutRecord.end_at <= end_at)

    records = db.scalars(stmt.order_by(desc(HealthWorkoutRecord.start_at)).limit(limit).offset(offset)).all()
    return WorkoutListResponse(items=[workout_record_to_schema(record) for record in records])


def list_sync_batches(
    db: Session,
    *,
    device_id: str | None = None,
    limit: int = 100,
    offset: int = 0,
) -> SyncBatchListResponse:
    stmt: Select[tuple[SyncBatchRecord]] = select(SyncBatchRecord)
    if device_id:
        stmt = stmt.where(SyncBatchRecord.device_id == device_id)

    records = db.scalars(stmt.order_by(desc(SyncBatchRecord.received_at)).limit(limit).offset(offset)).all()
    return SyncBatchListResponse(items=[sync_batch_record_to_schema(record) for record in records])


def metric_record_to_schema(record: HealthMetricRecord) -> HealthMetricOut:
    return HealthMetricOut(
        id=record.id,
        device_id=record.device_id,
        type=record.type,
        value=record.value,
        unit=record.unit,
        start_at=record.start_at,
        end_at=record.end_at,
        source_name=record.source_name,
        source_bundle_id=record.source_bundle_id,
        metadata=record.metadata_json or {},
        export_id=record.export_id,
    )


def workout_record_to_schema(record: HealthWorkoutRecord) -> HealthWorkoutOut:
    return HealthWorkoutOut(
        id=record.id,
        device_id=record.device_id,
        activity_type=record.activity_type,
        start_at=record.start_at,
        end_at=record.end_at,
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
