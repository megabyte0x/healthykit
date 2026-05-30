from __future__ import annotations

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "20260531_0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    metadata_type = postgresql.JSONB(astext_type=sa.Text()).with_variant(sa.JSON(), "sqlite")

    op.create_table(
        "devices",
        sa.Column("device_id", sa.String(length=128), primary_key=True),
        sa.Column("first_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("app_version", sa.String(length=64), nullable=True),
    )
    op.create_table(
        "sync_batches",
        sa.Column("export_id", sa.String(length=36), primary_key=True),
        sa.Column("device_id", sa.String(length=128), sa.ForeignKey("devices.device_id", ondelete="CASCADE"), nullable=False),
        sa.Column("generated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("schema_version", sa.Integer(), nullable=False),
        sa.Column("timezone", sa.String(length=128), nullable=False),
        sa.Column("source", sa.String(length=64), nullable=False),
        sa.Column("date_range_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("date_range_end", sa.DateTime(timezone=True), nullable=False),
        sa.Column("metrics_count", sa.Integer(), nullable=False),
        sa.Column("workouts_count", sa.Integer(), nullable=False),
    )
    op.create_index("ix_sync_batches_device_id", "sync_batches", ["device_id"])
    op.create_index("ix_sync_batches_device_received", "sync_batches", ["device_id", "received_at"])
    op.create_table(
        "health_metrics",
        sa.Column("device_id", sa.String(length=128), sa.ForeignKey("devices.device_id", ondelete="CASCADE"), primary_key=True),
        sa.Column("id", sa.String(length=256), primary_key=True),
        sa.Column("type", sa.String(length=128), nullable=False),
        sa.Column("value", sa.Float(), nullable=False),
        sa.Column("unit", sa.String(length=64), nullable=False),
        sa.Column("start_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("source_name", sa.String(length=256), nullable=False),
        sa.Column("source_bundle_id", sa.String(length=256), nullable=True),
        sa.Column("metadata", metadata_type, nullable=False),
        sa.Column("export_id", sa.String(length=36), sa.ForeignKey("sync_batches.export_id", ondelete="CASCADE"), nullable=False),
    )
    op.create_index("ix_health_metrics_device_type_start", "health_metrics", ["device_id", "type", "start_at"])
    op.create_index("ix_health_metrics_device_start", "health_metrics", ["device_id", "start_at"])
    op.create_table(
        "health_workouts",
        sa.Column("device_id", sa.String(length=128), sa.ForeignKey("devices.device_id", ondelete="CASCADE"), primary_key=True),
        sa.Column("id", sa.String(length=256), primary_key=True),
        sa.Column("activity_type", sa.String(length=128), nullable=False),
        sa.Column("start_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("duration_seconds", sa.Float(), nullable=False),
        sa.Column("total_energy_kcal", sa.Float(), nullable=True),
        sa.Column("active_energy_kcal", sa.Float(), nullable=True),
        sa.Column("distance_meters", sa.Float(), nullable=True),
        sa.Column("source_name", sa.String(length=256), nullable=False),
        sa.Column("source_bundle_id", sa.String(length=256), nullable=True),
        sa.Column("metadata", metadata_type, nullable=False),
        sa.Column("export_id", sa.String(length=36), sa.ForeignKey("sync_batches.export_id", ondelete="CASCADE"), nullable=False),
    )
    op.create_index("ix_health_workouts_device_activity_start", "health_workouts", ["device_id", "activity_type", "start_at"])
    op.create_index("ix_health_workouts_device_start", "health_workouts", ["device_id", "start_at"])


def downgrade() -> None:
    op.drop_index("ix_health_workouts_device_start", table_name="health_workouts")
    op.drop_index("ix_health_workouts_device_activity_start", table_name="health_workouts")
    op.drop_table("health_workouts")
    op.drop_index("ix_health_metrics_device_start", table_name="health_metrics")
    op.drop_index("ix_health_metrics_device_type_start", table_name="health_metrics")
    op.drop_table("health_metrics")
    op.drop_index("ix_sync_batches_device_received", table_name="sync_batches")
    op.drop_index("ix_sync_batches_device_id", table_name="sync_batches")
    op.drop_table("sync_batches")
    op.drop_table("devices")
