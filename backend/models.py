from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Index, Integer, JSON, String
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


class SyncBatchRecord(Base):
    __tablename__ = "sync_batches"

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
        Index("ix_sync_batches_device_received", "device_id", "received_at"),
    )


class HealthMetricRecord(Base):
    __tablename__ = "health_metrics"

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
    metadata_json: Mapped[dict[str, str]] = mapped_column(
        "metadata",
        json_metadata_type,
        nullable=False,
        default=dict,
    )
    export_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("sync_batches.export_id", ondelete="CASCADE"),
        nullable=False,
    )

    __table_args__ = (
        Index("ix_health_metrics_device_type_start", "device_id", "type", "start_at"),
        Index("ix_health_metrics_device_start", "device_id", "start_at"),
    )


class HealthWorkoutRecord(Base):
    __tablename__ = "health_workouts"

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
    metadata_json: Mapped[dict[str, str]] = mapped_column(
        "metadata",
        json_metadata_type,
        nullable=False,
        default=dict,
    )
    export_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("sync_batches.export_id", ondelete="CASCADE"),
        nullable=False,
    )

    __table_args__ = (
        Index("ix_health_workouts_device_activity_start", "device_id", "activity_type", "start_at"),
        Index("ix_health_workouts_device_start", "device_id", "start_at"),
    )
