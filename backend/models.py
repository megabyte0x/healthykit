from __future__ import annotations

from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Float, ForeignKey, ForeignKeyConstraint, Index, Integer, JSON, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


json_metadata_type = JSON().with_variant(JSONB, "postgresql")


class DeviceRecord(Base):
    __tablename__ = "devices"

    device_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    first_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    app_version: Mapped[str | None] = mapped_column(String(64), nullable=True)


class WorkspaceRecord(Base):
    __tablename__ = "workspaces"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    label: Mapped[str | None] = mapped_column(String(128), nullable=True)


class WorkspaceDeviceRecord(Base):
    __tablename__ = "workspace_devices"

    workspace_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("workspaces.id", ondelete="CASCADE"),
        primary_key=True,
    )
    device_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("devices.device_id", ondelete="CASCADE"),
        primary_key=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    label: Mapped[str | None] = mapped_column(String(128), nullable=True)


class AccessTokenRecord(Base):
    __tablename__ = "access_tokens"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    workspace_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("workspaces.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    kind: Mapped[str] = mapped_column(String(32), nullable=False)
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        CheckConstraint("kind IN ('ingest', 'agent_read')", name="ck_access_tokens_kind"),
        Index("ix_access_tokens_token_hash", "token_hash", unique=True),
    )


class SyncBatchRecord(Base):
    __tablename__ = "sync_batches"

    workspace_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("workspaces.id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
        default="self_hosted",
        index=True,
    )
    export_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    device_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("devices.device_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    generated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    schema_version: Mapped[int] = mapped_column(Integer, nullable=False)
    timezone: Mapped[str] = mapped_column(String(128), nullable=False)
    source: Mapped[str] = mapped_column(String(64), nullable=False)
    date_range_start: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    date_range_end: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    metrics_count: Mapped[int] = mapped_column(Integer, nullable=False)
    workouts_count: Mapped[int] = mapped_column(Integer, nullable=False)

    __table_args__ = (
        CheckConstraint("date_range_end >= date_range_start", name="ck_sync_batches_date_range_order"),
        CheckConstraint("metrics_count >= 0", name="ck_sync_batches_metrics_count_nonnegative"),
        CheckConstraint("workouts_count >= 0", name="ck_sync_batches_workouts_count_nonnegative"),
        Index("ix_sync_batches_device_received", "device_id", "received_at"),
        Index("ix_sync_batches_workspace_received", "workspace_id", "received_at"),
    )


class HealthMetricRecord(Base):
    __tablename__ = "health_metrics"

    workspace_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("workspaces.id", ondelete="CASCADE"),
        primary_key=True,
        default="self_hosted",
    )
    device_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("devices.device_id", ondelete="CASCADE"),
        primary_key=True,
    )
    id: Mapped[str] = mapped_column(String(256), primary_key=True)
    type: Mapped[str] = mapped_column(String(128), nullable=False)
    value: Mapped[float] = mapped_column(Float, nullable=False)
    unit: Mapped[str] = mapped_column(String(64), nullable=False)
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    source_name: Mapped[str] = mapped_column(String(256), nullable=False)
    source_bundle_id: Mapped[str | None] = mapped_column(String(256), nullable=True)
    metadata_json: Mapped[dict[str, object]] = mapped_column(
        "metadata",
        json_metadata_type,
        nullable=False,
        default=dict,
    )
    export_id: Mapped[str] = mapped_column(
        String(36),
        nullable=False,
    )

    __table_args__ = (
        CheckConstraint("end_at >= start_at", name="ck_health_metrics_time_order"),
        ForeignKeyConstraint(
            ["workspace_id", "export_id"],
            ["sync_batches.workspace_id", "sync_batches.export_id"],
            ondelete="CASCADE",
        ),
        Index("ix_health_metrics_device_type_start", "device_id", "type", "start_at"),
        Index("ix_health_metrics_device_start", "device_id", "start_at"),
        Index("ix_health_metrics_workspace_type_start", "workspace_id", "type", "start_at"),
    )


class HealthWorkoutRecord(Base):
    __tablename__ = "health_workouts"

    workspace_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("workspaces.id", ondelete="CASCADE"),
        primary_key=True,
        default="self_hosted",
    )
    device_id: Mapped[str] = mapped_column(
        String(128),
        ForeignKey("devices.device_id", ondelete="CASCADE"),
        primary_key=True,
    )
    id: Mapped[str] = mapped_column(String(256), primary_key=True)
    activity_type: Mapped[str] = mapped_column(String(128), nullable=False)
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    duration_seconds: Mapped[float] = mapped_column(Float, nullable=False)
    total_energy_kcal: Mapped[float | None] = mapped_column(Float, nullable=True)
    active_energy_kcal: Mapped[float | None] = mapped_column(Float, nullable=True)
    distance_meters: Mapped[float | None] = mapped_column(Float, nullable=True)
    source_name: Mapped[str] = mapped_column(String(256), nullable=False)
    source_bundle_id: Mapped[str | None] = mapped_column(String(256), nullable=True)
    metadata_json: Mapped[dict[str, object]] = mapped_column(
        "metadata",
        json_metadata_type,
        nullable=False,
        default=dict,
    )
    export_id: Mapped[str] = mapped_column(
        String(36),
        nullable=False,
    )

    __table_args__ = (
        CheckConstraint("end_at >= start_at", name="ck_health_workouts_time_order"),
        CheckConstraint("duration_seconds >= 0", name="ck_health_workouts_duration_nonnegative"),
        CheckConstraint(
            "total_energy_kcal IS NULL OR total_energy_kcal >= 0",
            name="ck_health_workouts_total_energy_nonnegative",
        ),
        CheckConstraint(
            "active_energy_kcal IS NULL OR active_energy_kcal >= 0",
            name="ck_health_workouts_active_energy_nonnegative",
        ),
        CheckConstraint(
            "distance_meters IS NULL OR distance_meters >= 0",
            name="ck_health_workouts_distance_nonnegative",
        ),
        ForeignKeyConstraint(
            ["workspace_id", "export_id"],
            ["sync_batches.workspace_id", "sync_batches.export_id"],
            ondelete="CASCADE",
        ),
        Index("ix_health_workouts_device_activity_start", "device_id", "activity_type", "start_at"),
        Index("ix_health_workouts_device_start", "device_id", "start_at"),
        Index("ix_health_workouts_workspace_activity_start", "workspace_id", "activity_type", "start_at"),
    )
