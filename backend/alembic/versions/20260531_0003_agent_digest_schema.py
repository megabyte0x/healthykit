from __future__ import annotations

from collections.abc import Sequence

from alembic import op

revision: str = "20260531_0003"
down_revision: str | None = "20260531_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    if op.get_bind().dialect.name != "sqlite":
        _create_check_constraints()
        _create_postgresql_views()
    else:
        _create_sqlite_views()


def downgrade() -> None:
    op.execute("DROP VIEW IF EXISTS agent_workout_daily_summaries")
    op.execute("DROP VIEW IF EXISTS agent_metric_daily_summaries")
    if op.get_bind().dialect.name != "sqlite":
        _drop_check_constraints()


def _create_check_constraints() -> None:
    op.create_check_constraint(
        "ck_access_tokens_kind",
        "access_tokens",
        "kind IN ('ingest', 'agent_read')",
    )
    op.create_check_constraint(
        "ck_sync_batches_date_range_order",
        "sync_batches",
        "date_range_end >= date_range_start",
    )
    op.create_check_constraint(
        "ck_sync_batches_metrics_count_nonnegative",
        "sync_batches",
        "metrics_count >= 0",
    )
    op.create_check_constraint(
        "ck_sync_batches_workouts_count_nonnegative",
        "sync_batches",
        "workouts_count >= 0",
    )
    op.create_check_constraint(
        "ck_health_metrics_time_order",
        "health_metrics",
        "end_at >= start_at",
    )
    op.create_check_constraint(
        "ck_health_workouts_time_order",
        "health_workouts",
        "end_at >= start_at",
    )
    op.create_check_constraint(
        "ck_health_workouts_duration_nonnegative",
        "health_workouts",
        "duration_seconds >= 0",
    )
    op.create_check_constraint(
        "ck_health_workouts_total_energy_nonnegative",
        "health_workouts",
        "total_energy_kcal IS NULL OR total_energy_kcal >= 0",
    )
    op.create_check_constraint(
        "ck_health_workouts_active_energy_nonnegative",
        "health_workouts",
        "active_energy_kcal IS NULL OR active_energy_kcal >= 0",
    )
    op.create_check_constraint(
        "ck_health_workouts_distance_nonnegative",
        "health_workouts",
        "distance_meters IS NULL OR distance_meters >= 0",
    )


def _drop_check_constraints() -> None:
    op.drop_constraint("ck_health_workouts_distance_nonnegative", "health_workouts", type_="check")
    op.drop_constraint("ck_health_workouts_active_energy_nonnegative", "health_workouts", type_="check")
    op.drop_constraint("ck_health_workouts_total_energy_nonnegative", "health_workouts", type_="check")
    op.drop_constraint("ck_health_workouts_duration_nonnegative", "health_workouts", type_="check")
    op.drop_constraint("ck_health_workouts_time_order", "health_workouts", type_="check")
    op.drop_constraint("ck_health_metrics_time_order", "health_metrics", type_="check")
    op.drop_constraint("ck_sync_batches_workouts_count_nonnegative", "sync_batches", type_="check")
    op.drop_constraint("ck_sync_batches_metrics_count_nonnegative", "sync_batches", type_="check")
    op.drop_constraint("ck_sync_batches_date_range_order", "sync_batches", type_="check")
    op.drop_constraint("ck_access_tokens_kind", "access_tokens", type_="check")


def _create_postgresql_views() -> None:
    op.execute(
        """
        CREATE VIEW agent_metric_daily_summaries
        WITH (security_invoker = true) AS
        SELECT
            m.workspace_id,
            (m.start_at AT TIME ZONE sb.timezone)::date AS local_date,
            m.type,
            m.unit,
            count(*)::integer AS sample_count,
            sum(m.value)::double precision AS total_value,
            avg(m.value)::double precision AS average_value,
            min(m.value)::double precision AS minimum_value,
            max(m.value)::double precision AS maximum_value,
            min(m.start_at) AS first_start_at,
            max(m.end_at) AS last_end_at
        FROM health_metrics AS m
        JOIN sync_batches AS sb
            ON sb.workspace_id = m.workspace_id
            AND sb.export_id = m.export_id
        GROUP BY
            m.workspace_id,
            (m.start_at AT TIME ZONE sb.timezone)::date,
            m.type,
            m.unit
        """
    )
    op.execute(
        """
        CREATE VIEW agent_workout_daily_summaries
        WITH (security_invoker = true) AS
        SELECT
            w.workspace_id,
            (w.start_at AT TIME ZONE sb.timezone)::date AS local_date,
            w.activity_type,
            count(*)::integer AS workout_count,
            (sum(w.duration_seconds) / 60.0)::double precision AS duration_minutes,
            CASE
                WHEN count(w.distance_meters) > 0 THEN (sum(w.distance_meters) / 1000.0)::double precision
                ELSE NULL
            END AS distance_km,
            CASE
                WHEN count(w.total_energy_kcal) > 0 THEN sum(w.total_energy_kcal)::double precision
                ELSE NULL
            END AS total_energy_kcal,
            CASE
                WHEN count(w.active_energy_kcal) > 0 THEN sum(w.active_energy_kcal)::double precision
                ELSE NULL
            END AS active_energy_kcal,
            min(w.start_at) AS first_start_at,
            max(w.end_at) AS last_end_at
        FROM health_workouts AS w
        JOIN sync_batches AS sb
            ON sb.workspace_id = w.workspace_id
            AND sb.export_id = w.export_id
        GROUP BY
            w.workspace_id,
            (w.start_at AT TIME ZONE sb.timezone)::date,
            w.activity_type
        """
    )


def _create_sqlite_views() -> None:
    op.execute(
        """
        CREATE VIEW agent_metric_daily_summaries AS
        SELECT
            m.workspace_id,
            date(m.start_at) AS local_date,
            m.type,
            m.unit,
            count(*) AS sample_count,
            sum(m.value) AS total_value,
            avg(m.value) AS average_value,
            min(m.value) AS minimum_value,
            max(m.value) AS maximum_value,
            min(m.start_at) AS first_start_at,
            max(m.end_at) AS last_end_at
        FROM health_metrics AS m
        JOIN sync_batches AS sb
            ON sb.workspace_id = m.workspace_id
            AND sb.export_id = m.export_id
        GROUP BY m.workspace_id, date(m.start_at), m.type, m.unit
        """
    )
    op.execute(
        """
        CREATE VIEW agent_workout_daily_summaries AS
        SELECT
            w.workspace_id,
            date(w.start_at) AS local_date,
            w.activity_type,
            count(*) AS workout_count,
            sum(w.duration_seconds) / 60.0 AS duration_minutes,
            CASE
                WHEN count(w.distance_meters) > 0 THEN sum(w.distance_meters) / 1000.0
                ELSE NULL
            END AS distance_km,
            CASE
                WHEN count(w.total_energy_kcal) > 0 THEN sum(w.total_energy_kcal)
                ELSE NULL
            END AS total_energy_kcal,
            CASE
                WHEN count(w.active_energy_kcal) > 0 THEN sum(w.active_energy_kcal)
                ELSE NULL
            END AS active_energy_kcal,
            min(w.start_at) AS first_start_at,
            max(w.end_at) AS last_end_at
        FROM health_workouts AS w
        JOIN sync_batches AS sb
            ON sb.workspace_id = w.workspace_id
            AND sb.export_id = w.export_id
        GROUP BY w.workspace_id, date(w.start_at), w.activity_type
        """
    )
