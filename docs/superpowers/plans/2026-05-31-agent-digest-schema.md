# Agent Digest Schema Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an agent-friendly HealthSync schema layer, migrate the current Supabase database, verify behavior, and push the backend changes.

**Architecture:** Keep the raw ingest tables stable and add a backwards-compatible digest layer. FastAPI enriches agent responses with catalog, pagination, local dates, and daily summaries, while Postgres gets SQL views and check constraints for safer direct inspection.

**Tech Stack:** FastAPI, Pydantic, SQLAlchemy, Alembic, Supabase Postgres, pytest.

---

### Task 1: Pin Agent Digest Contract

**Files:**
- Modify: `Tests/backend/test_backend_api.py`

- [x] **Step 1: Write failing tests for `/api/agent/health-data`**

Add tests proving the agent response returns `agent_schema_version`, `page`, `catalog`, typed metadata, timezone/local-date enrichment, `metric_daily_summaries`, and `workout_daily_summaries`.

- [x] **Step 2: Run the focused tests and verify red**

Run: `.venv/bin/python -m pytest Tests/backend/test_backend_api.py::test_agent_health_data_returns_digest_schema_for_agents Tests/backend/test_backend_api.py::test_agent_health_data_reports_has_more_when_result_is_limited -q`

Expected: fails because `agent_schema_version` and `page` are absent.

### Task 2: Implement Backend Digest Response

**Files:**
- Modify: `backend/schemas.py`
- Modify: `backend/repository.py`
- Modify: `backend/app.py`
- Modify: `backend/models.py`

- [x] **Step 1: Add response schemas**

Add `PageInfo`, `AgentCatalog`, `MetricDailySummary`, and `WorkoutDailySummary`; enrich metric/workout output with `timezone` and `local_date`.

- [x] **Step 2: Add repository helpers**

Add catalog queries, timezone lookup, local date derivation, limit-plus-one pagination, and daily summary aggregation.

- [x] **Step 3: Wire `/api/agent/health-data`**

Return schema version `2`, catalog, page metadata, raw rows, and summaries while preserving existing auth and workspace scoping.

- [x] **Step 4: Verify green**

Run: `.venv/bin/python -m pytest Tests/backend/test_backend_api.py -q`

Expected: all backend API tests pass.

### Task 3: Add Database Migration

**Files:**
- Create: `backend/alembic/versions/20260531_0003_agent_digest_schema.py`
- Modify: `backend/README.md`

- [x] **Step 1: Add Alembic migration**

Create check constraints for token kind, date ranges, counts, workout values, and sample time order. Create `agent_metric_daily_summaries` and `agent_workout_daily_summaries` views.

- [x] **Step 2: Document the agent schema**

Document digest response fields and SQL views in `backend/README.md`.

### Task 4: Migrate Supabase And Push

**Files:**
- Stage only backend/schema/docs changes.

- [ ] **Step 1: Run local migration smoke test**

Run: `env DATABASE_URL=sqlite+pysqlite:////private/tmp/healthsync-agent-schema.sqlite .venv/bin/alembic upgrade head`

Expected: migration reaches head without errors.

- [ ] **Step 2: Apply Supabase migration**

Use the Supabase migration tool against project `dtzydnjnqkruxaacgkio` with the same SQL intent as the Alembic migration.

- [ ] **Step 3: Verify**

Run backend tests, compile backend files, inspect Supabase tables/migrations, and verify git diff.

- [ ] **Step 4: Commit and push**

Commit only intended backend/docs/test migration changes and push branch `codex/supabase-agent-schema`.
