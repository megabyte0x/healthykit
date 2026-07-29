from __future__ import annotations

from collections.abc import Sequence

from alembic import op

revision: str = "20260729_0005"
down_revision: str | None = "20260605_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    if op.get_bind().dialect.name == "sqlite":
        _create_sqlite_view(canonical=True)
    else:
        _create_postgresql_view(canonical=True)


def downgrade() -> None:
    if op.get_bind().dialect.name == "sqlite":
        _create_sqlite_view(canonical=False)
    else:
        _create_postgresql_view(canonical=False)


def _create_postgresql_view(*, canonical: bool) -> None:
    if not canonical:
        op.execute(
            """
            CREATE OR REPLACE VIEW agent_metric_daily_summaries
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
        return

    op.execute(
        """
        CREATE OR REPLACE VIEW agent_metric_daily_summaries
        WITH (security_invoker = true) AS
        WITH metric_rows AS (
            SELECT
                m.workspace_id,
                m.device_id,
                (m.start_at AT TIME ZONE sb.timezone)::date AS local_date,
                m.type,
                m.unit,
                m.value,
                m.start_at,
                m.end_at,
                m.metadata->>'aggregation' IN ('daily_sum', 'daily_average') AS is_daily_aggregate,
                bool_or(m.metadata->>'aggregation' IN ('daily_sum', 'daily_average')) OVER (
                    PARTITION BY
                        m.workspace_id,
                        m.device_id,
                        (m.start_at AT TIME ZONE sb.timezone)::date,
                        m.type,
                        m.unit
                ) AS has_daily_aggregate
            FROM health_metrics AS m
            JOIN sync_batches AS sb
                ON sb.workspace_id = m.workspace_id
                AND sb.export_id = m.export_id
        ),
        canonical_metric_rows AS (
            SELECT *
            FROM metric_rows
            WHERE is_daily_aggregate OR NOT has_daily_aggregate
        )
        SELECT
            workspace_id,
            local_date,
            type,
            unit,
            count(*)::integer AS sample_count,
            sum(value)::double precision AS total_value,
            avg(value)::double precision AS average_value,
            min(value)::double precision AS minimum_value,
            max(value)::double precision AS maximum_value,
            min(start_at) AS first_start_at,
            max(end_at) AS last_end_at
        FROM canonical_metric_rows
        GROUP BY workspace_id, local_date, type, unit
        """
    )


def _create_sqlite_view(*, canonical: bool) -> None:
    op.execute("DROP VIEW IF EXISTS agent_metric_daily_summaries")
    if not canonical:
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
        return

    op.execute(
        """
        CREATE VIEW agent_metric_daily_summaries AS
        WITH metric_rows AS (
            SELECT
                m.workspace_id,
                m.device_id,
                date(m.start_at) AS local_date,
                m.type,
                m.unit,
                m.value,
                m.start_at,
                m.end_at,
                json_extract(m.metadata, '$.aggregation') IN ('daily_sum', 'daily_average') AS is_daily_aggregate,
                max(json_extract(m.metadata, '$.aggregation') IN ('daily_sum', 'daily_average')) OVER (
                    PARTITION BY m.workspace_id, m.device_id, date(m.start_at), m.type, m.unit
                ) AS has_daily_aggregate
            FROM health_metrics AS m
            JOIN sync_batches AS sb
                ON sb.workspace_id = m.workspace_id
                AND sb.export_id = m.export_id
        )
        SELECT
            workspace_id,
            local_date,
            type,
            unit,
            count(*) AS sample_count,
            sum(value) AS total_value,
            avg(value) AS average_value,
            min(value) AS minimum_value,
            max(value) AS maximum_value,
            min(start_at) AS first_start_at,
            max(end_at) AS last_end_at
        FROM metric_rows
        WHERE is_daily_aggregate OR NOT has_daily_aggregate
        GROUP BY workspace_id, local_date, type, unit
        """
    )
