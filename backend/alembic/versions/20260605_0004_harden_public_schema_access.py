from __future__ import annotations

from collections.abc import Sequence

from alembic import op

revision: str = "20260605_0004"
down_revision: str | None = "20260531_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    if op.get_bind().dialect.name == "sqlite":
        return

    op.execute(
        """
        REVOKE ALL PRIVILEGES ON SCHEMA public FROM PUBLIC, anon, authenticated;
        REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon, authenticated;
        REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, anon, authenticated;
        REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;

        GRANT USAGE ON SCHEMA public TO service_role;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO service_role;
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO service_role;
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO service_role;

        ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
            REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
        ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
            REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated;
        ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
            REVOKE ALL ON FUNCTIONS FROM PUBLIC, anon, authenticated;
        ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
            GRANT ALL ON TABLES TO service_role;
        ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
            GRANT ALL ON SEQUENCES TO service_role;
        ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
            GRANT ALL ON FUNCTIONS TO service_role;

        DO $$
        DECLARE
            table_record record;
        BEGIN
            FOR table_record IN
                SELECT schemaname, tablename
                FROM pg_tables
                WHERE schemaname = 'public'
            LOOP
                EXECUTE format(
                    'ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY',
                    table_record.schemaname,
                    table_record.tablename
                );
            END LOOP;
        END $$;
        """
    )


def downgrade() -> None:
    # Keep this hardening sticky: downgrading should not re-open direct public access.
    return
