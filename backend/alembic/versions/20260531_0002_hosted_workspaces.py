from __future__ import annotations

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20260531_0002"
down_revision: str | None = "20260531_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SELF_HOSTED_WORKSPACE_ID = "self_hosted"


def upgrade() -> None:
    op.create_table(
        "workspaces",
        sa.Column("id", sa.String(length=64), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("label", sa.String(length=128), nullable=True),
    )
    op.bulk_insert(
        sa.table(
            "workspaces",
            sa.column("id", sa.String(length=64)),
            sa.column("label", sa.String(length=128)),
        ),
        [{"id": SELF_HOSTED_WORKSPACE_ID, "label": "Self Hosted"}],
    )
    op.create_table(
        "workspace_devices",
        sa.Column("workspace_id", sa.String(length=64), nullable=False),
        sa.Column("device_id", sa.String(length=128), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("label", sa.String(length=128), nullable=True),
        sa.ForeignKeyConstraint(["workspace_id"], ["workspaces.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["device_id"], ["devices.device_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("workspace_id", "device_id"),
    )
    op.create_table(
        "access_tokens",
        sa.Column("id", sa.String(length=64), primary_key=True),
        sa.Column("workspace_id", sa.String(length=64), nullable=False),
        sa.Column("kind", sa.String(length=32), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["workspace_id"], ["workspaces.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_access_tokens_workspace_id", "access_tokens", ["workspace_id"])
    op.create_index("ix_access_tokens_token_hash", "access_tokens", ["token_hash"], unique=True)

    if op.get_bind().dialect.name == "sqlite":
        _upgrade_sync_tables_sqlite()
    else:
        _upgrade_sync_tables_postgresql()


def downgrade() -> None:
    if op.get_bind().dialect.name == "sqlite":
        _downgrade_sync_tables_sqlite()
    else:
        _downgrade_sync_tables_postgresql()

    op.drop_index("ix_access_tokens_token_hash", table_name="access_tokens")
    op.drop_index("ix_access_tokens_workspace_id", table_name="access_tokens")
    op.drop_table("access_tokens")
    op.drop_table("workspace_devices")
    op.drop_table("workspaces")


def _upgrade_sync_tables_postgresql() -> None:
    op.add_column(
        "sync_batches",
        sa.Column(
            "workspace_id",
            sa.String(length=64),
            sa.ForeignKey("workspaces.id", ondelete="CASCADE"),
            nullable=False,
            server_default=SELF_HOSTED_WORKSPACE_ID,
        ),
    )
    op.drop_constraint("health_metrics_export_id_fkey", "health_metrics", type_="foreignkey")
    op.drop_constraint("health_workouts_export_id_fkey", "health_workouts", type_="foreignkey")
    op.drop_constraint("sync_batches_pkey", "sync_batches", type_="primary")
    op.create_primary_key("sync_batches_pkey", "sync_batches", ["workspace_id", "export_id"])
    op.create_index("ix_sync_batches_workspace_id", "sync_batches", ["workspace_id"])
    op.create_index("ix_sync_batches_workspace_received", "sync_batches", ["workspace_id", "received_at"])

    op.add_column(
        "health_metrics",
        sa.Column("workspace_id", sa.String(length=64), nullable=False, server_default=SELF_HOSTED_WORKSPACE_ID),
    )
    op.create_foreign_key(
        "fk_health_metrics_workspace_id_workspaces",
        "health_metrics",
        "workspaces",
        ["workspace_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "fk_health_metrics_workspace_export_sync_batches",
        "health_metrics",
        "sync_batches",
        ["workspace_id", "export_id"],
        ["workspace_id", "export_id"],
        ondelete="CASCADE",
    )
    op.drop_constraint("health_metrics_pkey", "health_metrics", type_="primary")
    op.create_primary_key("health_metrics_pkey", "health_metrics", ["workspace_id", "device_id", "id"])
    op.create_index("ix_health_metrics_workspace_type_start", "health_metrics", ["workspace_id", "type", "start_at"])

    op.add_column(
        "health_workouts",
        sa.Column("workspace_id", sa.String(length=64), nullable=False, server_default=SELF_HOSTED_WORKSPACE_ID),
    )
    op.create_foreign_key(
        "fk_health_workouts_workspace_id_workspaces",
        "health_workouts",
        "workspaces",
        ["workspace_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "fk_health_workouts_workspace_export_sync_batches",
        "health_workouts",
        "sync_batches",
        ["workspace_id", "export_id"],
        ["workspace_id", "export_id"],
        ondelete="CASCADE",
    )
    op.drop_constraint("health_workouts_pkey", "health_workouts", type_="primary")
    op.create_primary_key("health_workouts_pkey", "health_workouts", ["workspace_id", "device_id", "id"])
    op.create_index(
        "ix_health_workouts_workspace_activity_start",
        "health_workouts",
        ["workspace_id", "activity_type", "start_at"],
    )


def _downgrade_sync_tables_postgresql() -> None:
    op.drop_index("ix_health_workouts_workspace_activity_start", table_name="health_workouts")
    op.drop_constraint("health_workouts_pkey", "health_workouts", type_="primary")
    op.create_primary_key("health_workouts_pkey", "health_workouts", ["device_id", "id"])
    op.drop_constraint("fk_health_workouts_workspace_export_sync_batches", "health_workouts", type_="foreignkey")
    op.drop_constraint("fk_health_workouts_workspace_id_workspaces", "health_workouts", type_="foreignkey")
    op.drop_column("health_workouts", "workspace_id")

    op.drop_index("ix_health_metrics_workspace_type_start", table_name="health_metrics")
    op.drop_constraint("health_metrics_pkey", "health_metrics", type_="primary")
    op.create_primary_key("health_metrics_pkey", "health_metrics", ["device_id", "id"])
    op.drop_constraint("fk_health_metrics_workspace_export_sync_batches", "health_metrics", type_="foreignkey")
    op.drop_constraint("fk_health_metrics_workspace_id_workspaces", "health_metrics", type_="foreignkey")
    op.drop_column("health_metrics", "workspace_id")

    op.drop_index("ix_sync_batches_workspace_received", table_name="sync_batches")
    op.drop_index("ix_sync_batches_workspace_id", table_name="sync_batches")
    op.drop_constraint("sync_batches_pkey", "sync_batches", type_="primary")
    op.create_primary_key("sync_batches_pkey", "sync_batches", ["export_id"])
    op.create_foreign_key(
        "health_metrics_export_id_fkey",
        "health_metrics",
        "sync_batches",
        ["export_id"],
        ["export_id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "health_workouts_export_id_fkey",
        "health_workouts",
        "sync_batches",
        ["export_id"],
        ["export_id"],
        ondelete="CASCADE",
    )
    op.drop_column("sync_batches", "workspace_id")


def _upgrade_sync_tables_sqlite() -> None:
    _recreate_sync_batches_sqlite()
    _recreate_health_metrics_sqlite()
    _recreate_health_workouts_sqlite()


def _downgrade_sync_tables_sqlite() -> None:
    _recreate_health_workouts_sqlite(include_workspace=False)
    _recreate_health_metrics_sqlite(include_workspace=False)

    _recreate_sync_batches_sqlite(include_workspace=False)


def _recreate_sync_batches_sqlite(*, include_workspace: bool = True) -> None:
    source_table = "sync_batches"
    backup_table = "_sync_batches_old"
    op.execute("DROP INDEX IF EXISTS ix_sync_batches_workspace_received")
    op.execute("DROP INDEX IF EXISTS ix_sync_batches_workspace_id")
    op.execute("DROP INDEX IF EXISTS ix_sync_batches_device_received")
    op.execute("DROP INDEX IF EXISTS ix_sync_batches_device_id")
    op.rename_table(source_table, backup_table)
    if include_workspace:
        op.create_table(
            source_table,
            sa.Column("workspace_id", sa.String(length=64), nullable=False, server_default=SELF_HOSTED_WORKSPACE_ID),
            sa.Column("export_id", sa.String(length=36), nullable=False),
            sa.Column("device_id", sa.String(length=128), nullable=False),
            sa.Column("generated_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("received_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("schema_version", sa.Integer(), nullable=False),
            sa.Column("timezone", sa.String(length=128), nullable=False),
            sa.Column("source", sa.String(length=64), nullable=False),
            sa.Column("date_range_start", sa.DateTime(timezone=True), nullable=False),
            sa.Column("date_range_end", sa.DateTime(timezone=True), nullable=False),
            sa.Column("metrics_count", sa.Integer(), nullable=False),
            sa.Column("workouts_count", sa.Integer(), nullable=False),
            sa.ForeignKeyConstraint(["workspace_id"], ["workspaces.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["device_id"], ["devices.device_id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("workspace_id", "export_id"),
        )
        op.execute(
            """
            INSERT INTO sync_batches (
                workspace_id, export_id, device_id, generated_at, received_at, schema_version,
                timezone, source, date_range_start, date_range_end, metrics_count, workouts_count
            )
            SELECT 'self_hosted', export_id, device_id, generated_at, received_at, schema_version,
                timezone, source, date_range_start, date_range_end, metrics_count, workouts_count
            FROM _sync_batches_old
            """
        )
        op.create_index("ix_sync_batches_workspace_id", source_table, ["workspace_id"])
        op.create_index("ix_sync_batches_workspace_received", source_table, ["workspace_id", "received_at"])
    else:
        op.create_table(
            source_table,
            sa.Column("export_id", sa.String(length=36), nullable=False),
            sa.Column("device_id", sa.String(length=128), nullable=False),
            sa.Column("generated_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("received_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("schema_version", sa.Integer(), nullable=False),
            sa.Column("timezone", sa.String(length=128), nullable=False),
            sa.Column("source", sa.String(length=64), nullable=False),
            sa.Column("date_range_start", sa.DateTime(timezone=True), nullable=False),
            sa.Column("date_range_end", sa.DateTime(timezone=True), nullable=False),
            sa.Column("metrics_count", sa.Integer(), nullable=False),
            sa.Column("workouts_count", sa.Integer(), nullable=False),
            sa.ForeignKeyConstraint(["device_id"], ["devices.device_id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("export_id"),
        )
        op.execute(
            """
            INSERT INTO sync_batches (
                export_id, device_id, generated_at, received_at, schema_version,
                timezone, source, date_range_start, date_range_end, metrics_count, workouts_count
            )
            SELECT export_id, device_id, generated_at, received_at, schema_version,
                timezone, source, date_range_start, date_range_end, metrics_count, workouts_count
            FROM _sync_batches_old
            """
        )
    op.create_index("ix_sync_batches_device_id", source_table, ["device_id"])
    op.create_index("ix_sync_batches_device_received", source_table, ["device_id", "received_at"])
    op.drop_table(backup_table)


def _recreate_health_metrics_sqlite(*, include_workspace: bool = True) -> None:
    source_table = "health_metrics"
    backup_table = "_health_metrics_old"
    op.execute("DROP INDEX IF EXISTS ix_health_metrics_workspace_type_start")
    op.execute("DROP INDEX IF EXISTS ix_health_metrics_device_start")
    op.execute("DROP INDEX IF EXISTS ix_health_metrics_device_type_start")
    op.rename_table(source_table, backup_table)
    if include_workspace:
        op.create_table(
            source_table,
            sa.Column("workspace_id", sa.String(length=64), nullable=False, server_default=SELF_HOSTED_WORKSPACE_ID),
            sa.Column("device_id", sa.String(length=128), nullable=False),
            sa.Column("id", sa.String(length=256), nullable=False),
            sa.Column("type", sa.String(length=128), nullable=False),
            sa.Column("value", sa.Float(), nullable=False),
            sa.Column("unit", sa.String(length=64), nullable=False),
            sa.Column("start_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("end_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("source_name", sa.String(length=256), nullable=False),
            sa.Column("source_bundle_id", sa.String(length=256), nullable=True),
            sa.Column("metadata", sa.JSON(), nullable=False),
            sa.Column("export_id", sa.String(length=36), nullable=False),
            sa.ForeignKeyConstraint(["workspace_id"], ["workspaces.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["device_id"], ["devices.device_id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(
                ["workspace_id", "export_id"],
                ["sync_batches.workspace_id", "sync_batches.export_id"],
                ondelete="CASCADE",
            ),
            sa.PrimaryKeyConstraint("workspace_id", "device_id", "id"),
        )
        op.execute(
            """
            INSERT INTO health_metrics (
                workspace_id, device_id, id, type, value, unit, start_at, end_at,
                source_name, source_bundle_id, metadata, export_id
            )
            SELECT 'self_hosted', device_id, id, type, value, unit, start_at, end_at,
                source_name, source_bundle_id, metadata, export_id
            FROM _health_metrics_old
            """
        )
        op.create_index("ix_health_metrics_workspace_type_start", source_table, ["workspace_id", "type", "start_at"])
    else:
        op.create_table(
            source_table,
            sa.Column("device_id", sa.String(length=128), nullable=False),
            sa.Column("id", sa.String(length=256), nullable=False),
            sa.Column("type", sa.String(length=128), nullable=False),
            sa.Column("value", sa.Float(), nullable=False),
            sa.Column("unit", sa.String(length=64), nullable=False),
            sa.Column("start_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("end_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("source_name", sa.String(length=256), nullable=False),
            sa.Column("source_bundle_id", sa.String(length=256), nullable=True),
            sa.Column("metadata", sa.JSON(), nullable=False),
            sa.Column("export_id", sa.String(length=36), nullable=False),
            sa.ForeignKeyConstraint(["device_id"], ["devices.device_id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["export_id"], ["sync_batches.export_id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("device_id", "id"),
        )
        op.execute(
            """
            INSERT INTO health_metrics (
                device_id, id, type, value, unit, start_at, end_at,
                source_name, source_bundle_id, metadata, export_id
            )
            SELECT device_id, id, type, value, unit, start_at, end_at,
                source_name, source_bundle_id, metadata, export_id
            FROM _health_metrics_old
            """
        )
    op.create_index("ix_health_metrics_device_type_start", source_table, ["device_id", "type", "start_at"])
    op.create_index("ix_health_metrics_device_start", source_table, ["device_id", "start_at"])
    op.drop_table(backup_table)


def _recreate_health_workouts_sqlite(*, include_workspace: bool = True) -> None:
    source_table = "health_workouts"
    backup_table = "_health_workouts_old"
    op.execute("DROP INDEX IF EXISTS ix_health_workouts_workspace_activity_start")
    op.execute("DROP INDEX IF EXISTS ix_health_workouts_device_start")
    op.execute("DROP INDEX IF EXISTS ix_health_workouts_device_activity_start")
    op.rename_table(source_table, backup_table)
    if include_workspace:
        op.create_table(
            source_table,
            sa.Column("workspace_id", sa.String(length=64), nullable=False, server_default=SELF_HOSTED_WORKSPACE_ID),
            sa.Column("device_id", sa.String(length=128), nullable=False),
            sa.Column("id", sa.String(length=256), nullable=False),
            sa.Column("activity_type", sa.String(length=128), nullable=False),
            sa.Column("start_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("end_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("duration_seconds", sa.Float(), nullable=False),
            sa.Column("total_energy_kcal", sa.Float(), nullable=True),
            sa.Column("active_energy_kcal", sa.Float(), nullable=True),
            sa.Column("distance_meters", sa.Float(), nullable=True),
            sa.Column("source_name", sa.String(length=256), nullable=False),
            sa.Column("source_bundle_id", sa.String(length=256), nullable=True),
            sa.Column("metadata", sa.JSON(), nullable=False),
            sa.Column("export_id", sa.String(length=36), nullable=False),
            sa.ForeignKeyConstraint(["workspace_id"], ["workspaces.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["device_id"], ["devices.device_id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(
                ["workspace_id", "export_id"],
                ["sync_batches.workspace_id", "sync_batches.export_id"],
                ondelete="CASCADE",
            ),
            sa.PrimaryKeyConstraint("workspace_id", "device_id", "id"),
        )
        op.execute(
            """
            INSERT INTO health_workouts (
                workspace_id, device_id, id, activity_type, start_at, end_at, duration_seconds,
                total_energy_kcal, active_energy_kcal, distance_meters,
                source_name, source_bundle_id, metadata, export_id
            )
            SELECT 'self_hosted', device_id, id, activity_type, start_at, end_at, duration_seconds,
                total_energy_kcal, active_energy_kcal, distance_meters,
                source_name, source_bundle_id, metadata, export_id
            FROM _health_workouts_old
            """
        )
        op.create_index(
            "ix_health_workouts_workspace_activity_start",
            source_table,
            ["workspace_id", "activity_type", "start_at"],
        )
    else:
        op.create_table(
            source_table,
            sa.Column("device_id", sa.String(length=128), nullable=False),
            sa.Column("id", sa.String(length=256), nullable=False),
            sa.Column("activity_type", sa.String(length=128), nullable=False),
            sa.Column("start_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("end_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("duration_seconds", sa.Float(), nullable=False),
            sa.Column("total_energy_kcal", sa.Float(), nullable=True),
            sa.Column("active_energy_kcal", sa.Float(), nullable=True),
            sa.Column("distance_meters", sa.Float(), nullable=True),
            sa.Column("source_name", sa.String(length=256), nullable=False),
            sa.Column("source_bundle_id", sa.String(length=256), nullable=True),
            sa.Column("metadata", sa.JSON(), nullable=False),
            sa.Column("export_id", sa.String(length=36), nullable=False),
            sa.ForeignKeyConstraint(["device_id"], ["devices.device_id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["export_id"], ["sync_batches.export_id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("device_id", "id"),
        )
        op.execute(
            """
            INSERT INTO health_workouts (
                device_id, id, activity_type, start_at, end_at, duration_seconds,
                total_energy_kcal, active_energy_kcal, distance_meters,
                source_name, source_bundle_id, metadata, export_id
            )
            SELECT device_id, id, activity_type, start_at, end_at, duration_seconds,
                total_energy_kcal, active_energy_kcal, distance_meters,
                source_name, source_bundle_id, metadata, export_id
            FROM _health_workouts_old
            """
        )
    op.create_index("ix_health_workouts_device_activity_start", source_table, ["device_id", "activity_type", "start_at"])
    op.create_index("ix_health_workouts_device_start", source_table, ["device_id", "start_at"])
    op.drop_table(backup_table)
