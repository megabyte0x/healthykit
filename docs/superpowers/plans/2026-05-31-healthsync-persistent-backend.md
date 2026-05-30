# HealthSync Persistent Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real persistent backend for HealthSync with Docker/self-hosted and managed Postgres setup paths.

**Architecture:** Add a new `backend` FastAPI package that keeps the existing iOS upload endpoint stable, validates bearer tokens, persists devices/sync batches/metrics/workouts through SQLAlchemy, and exposes read endpoints for persisted data. Docker Compose runs the API and Postgres locally, while managed Postgres uses the same `DATABASE_URL` and Alembic migrations.

**Tech Stack:** Python 3.12, FastAPI, SQLAlchemy 2, Alembic, psycopg 3, Postgres, SQLite-backed pytest tests, Docker Compose.

---

## File Structure

- Create `backend/__init__.py`: marks the real backend package.
- Create `backend/app.py`: FastAPI application factory, auth dependency, upload/read routes.
- Create `backend/config.py`: environment-backed settings.
- Create `backend/database.py`: SQLAlchemy engine/session helpers.
- Create `backend/models.py`: SQLAlchemy table definitions.
- Create `backend/schemas.py`: Pydantic request/response schemas matching the iOS payload.
- Create `backend/repository.py`: transactional persistence and query functions.
- Create `backend/main.py`: ASGI entrypoint for `uvicorn backend.main:app`.
- Create `backend/scripts/generate_token.py`: token helper.
- Create `backend/Dockerfile`: production API image.
- Create `backend/requirements.txt`: runtime and test dependencies.
- Create `backend/alembic/env.py` and `backend/alembic/versions/20260531_0001_initial.py`: migrations.
- Create `alembic.ini`: Alembic config.
- Create `.env.example`: local and managed Postgres environment template.
- Create `docker-compose.yml`: API + Postgres local stack.
- Create `Tests/backend/test_backend_api.py`: backend persistence tests.
- Modify `README.md`: point users to the real backend setup.
- Modify `backend_stub/README.md`: explain that the stub is local-only and the persistent backend is in `backend/`.

---

### Task 1: Add Backend Tests First

**Files:**
- Create: `Tests/backend/test_backend_api.py`

- [ ] **Step 1: Write failing API persistence tests**

Create tests that instantiate `create_app()` with a temporary SQLite database and a known token. The tests must verify auth failures, successful persistence, duplicate handling, metric filters, workout filters, and sync listing.

```python
from __future__ import annotations

from pathlib import Path

from fastapi.testclient import TestClient

from backend.app import create_app
from backend.config import Settings
from backend.database import create_engine_for_url, create_session_factory
from backend.models import Base


def make_client(tmp_path: Path) -> TestClient:
    database_url = f"sqlite+pysqlite:///{tmp_path / 'healthsync.sqlite'}"
    engine = create_engine_for_url(database_url)
    Base.metadata.create_all(engine)
    session_factory = create_session_factory(engine)
    app = create_app(Settings(database_url=database_url, api_token="test-token"), session_factory=session_factory)
    return TestClient(app)


def sample_payload(export_id: str = "11111111-1111-4111-8111-111111111111") -> dict:
    return {
        "device_id": "device-1",
        "export_id": export_id,
        "generated_at": "2026-05-31T10:00:00.000Z",
        "timezone": "Asia/Kolkata",
        "source": "ios-healthkit",
        "schema_version": 1,
        "date_range": {
            "start": "2026-05-30T10:00:00.000Z",
            "end": "2026-05-31T10:00:00.000Z",
        },
        "metrics": [
            {
                "id": "healthkit:metric-1",
                "type": "stepCount",
                "value": 1200,
                "unit": "count",
                "start_at": "2026-05-31T09:00:00.000Z",
                "end_at": "2026-05-31T10:00:00.000Z",
                "source_name": "iPhone",
                "source_bundle_id": "com.apple.Health",
                "metadata": {"HKWasUserEntered": "false"},
            }
        ],
        "workouts": [
            {
                "id": "healthkit:workout-1",
                "activity_type": "running",
                "start_at": "2026-05-31T08:00:00.000Z",
                "end_at": "2026-05-31T08:30:00.000Z",
                "duration_seconds": 1800,
                "total_energy_kcal": 250,
                "active_energy_kcal": 230,
                "distance_meters": 5000,
                "source_name": "Apple Watch",
                "source_bundle_id": "com.apple.Health",
                "metadata": {"weather": "clear"},
            }
        ],
    }
```

- [ ] **Step 2: Add expected test cases**

```python
def test_sync_requires_bearer_token(tmp_path: Path) -> None:
    client = make_client(tmp_path)
    response = client.post("/api/apple-health/sync", json=sample_payload())
    assert response.status_code == 401


def test_sync_rejects_wrong_token(tmp_path: Path) -> None:
    client = make_client(tmp_path)
    response = client.post(
        "/api/apple-health/sync",
        headers={"Authorization": "Bearer wrong-token"},
        json=sample_payload(),
    )
    assert response.status_code == 403


def test_sync_persists_and_dedupes_records(tmp_path: Path) -> None:
    client = make_client(tmp_path)
    headers = {"Authorization": "Bearer test-token", "X-App-Version": "1.0"}

    first = client.post("/api/apple-health/sync", headers=headers, json=sample_payload())
    assert first.status_code == 200
    assert first.json() == {"ok": True, "received": 2, "duplicates": 0}

    second = client.post("/api/apple-health/sync", headers=headers, json=sample_payload())
    assert second.status_code == 200
    assert second.json() == {"ok": True, "received": 2, "duplicates": 2}


def test_fetch_metrics_workouts_and_syncs(tmp_path: Path) -> None:
    client = make_client(tmp_path)
    headers = {"Authorization": "Bearer test-token"}
    client.post("/api/apple-health/sync", headers=headers, json=sample_payload())

    metrics = client.get("/api/apple-health/metrics?device_id=device-1&type=stepCount", headers=headers)
    assert metrics.status_code == 200
    assert metrics.json()["items"][0]["id"] == "healthkit:metric-1"

    workouts = client.get("/api/apple-health/workouts?device_id=device-1", headers=headers)
    assert workouts.status_code == 200
    assert workouts.json()["items"][0]["id"] == "healthkit:workout-1"

    syncs = client.get("/api/apple-health/syncs?device_id=device-1", headers=headers)
    assert syncs.status_code == 200
    assert syncs.json()["items"][0]["export_id"] == "11111111-1111-4111-8111-111111111111"
```

- [ ] **Step 3: Run test to verify failure**

Run:

```bash
python3 -m pytest Tests/backend/test_backend_api.py -q
```

Expected: fails because `backend.app`, `backend.config`, `backend.database`, and `backend.models` do not exist yet.

---

### Task 2: Implement Backend Package

**Files:**
- Create: `backend/__init__.py`
- Create: `backend/config.py`
- Create: `backend/database.py`
- Create: `backend/models.py`
- Create: `backend/schemas.py`
- Create: `backend/repository.py`
- Create: `backend/app.py`
- Create: `backend/main.py`

- [ ] **Step 1: Add settings and database helpers**

`backend/config.py` must load `DATABASE_URL` and `API_TOKEN`, and `backend/database.py` must create SQLAlchemy engines and per-request sessions.

- [ ] **Step 2: Add SQLAlchemy models**

`backend/models.py` must define `devices`, `sync_batches`, `health_metrics`, and `health_workouts` with the columns named in the design spec. Use a JSON column with a Postgres JSONB variant.

- [ ] **Step 3: Add Pydantic schemas**

`backend/schemas.py` must define request models for the current iOS payload and response models for upload results, metrics, workouts, and sync batch lists.

- [ ] **Step 4: Add repository functions**

`backend/repository.py` must expose:

```python
persist_sync_payload(db, payload, app_version) -> UploadResult
list_metrics(db, filters) -> list[MetricResponse]
list_workouts(db, filters) -> list[WorkoutResponse]
list_sync_batches(db, filters) -> list[SyncBatchResponse]
```

Persistence must update duplicate rows instead of inserting duplicates.

- [ ] **Step 5: Add FastAPI routes**

`backend/app.py` must expose:

```text
GET /health
POST /api/apple-health/sync
GET /api/apple-health/metrics
GET /api/apple-health/workouts
GET /api/apple-health/syncs
```

All Apple Health endpoints must require `Authorization: Bearer <API_TOKEN>`.

- [ ] **Step 6: Run backend tests**

Run:

```bash
python3 -m pytest Tests/backend/test_backend_api.py -q
```

Expected: all backend tests pass.

---

### Task 3: Add Migrations and Runtime Setup

**Files:**
- Create: `alembic.ini`
- Create: `backend/alembic/env.py`
- Create: `backend/alembic/versions/20260531_0001_initial.py`
- Create: `backend/Dockerfile`
- Create: `backend/requirements.txt`
- Create: `.env.example`
- Create: `docker-compose.yml`
- Create: `backend/scripts/generate_token.py`

- [ ] **Step 1: Add Alembic migration**

Create migration `20260531_0001_initial.py` with `upgrade()` creating the four tables and indexes, and `downgrade()` dropping them in reverse order.

- [ ] **Step 2: Add Docker setup**

Create Docker Compose services:

```yaml
services:
  db:
    image: postgres:16-alpine
  api:
    build:
      context: .
      dockerfile: backend/Dockerfile
```

The API command must run `alembic upgrade head` before starting `uvicorn backend.main:app --host 0.0.0.0 --port 8080`.

- [ ] **Step 3: Add token helper**

`backend/scripts/generate_token.py` must print a URL-safe random token suitable for `.env`.

- [ ] **Step 4: Verify migration config imports**

Run:

```bash
python3 -m py_compile backend/alembic/env.py backend/alembic/versions/20260531_0001_initial.py backend/scripts/generate_token.py
```

Expected: command exits successfully.

---

### Task 4: Document User Setup

**Files:**
- Modify: `README.md`
- Modify: `backend_stub/README.md`
- Create: `backend/README.md`

- [ ] **Step 1: Document Docker setup**

`backend/README.md` must include exact commands:

```bash
cp .env.example .env
python3 -m backend.scripts.generate_token
docker compose up --build
```

- [ ] **Step 2: Document managed Postgres setup**

Document Supabase and Neon setup using the same `DATABASE_URL`, `API_TOKEN`, and `alembic upgrade head` flow.

- [ ] **Step 3: Document fetch examples**

Include `curl` examples for syncing, fetching metrics, fetching workouts, and listing sync batches.

- [ ] **Step 4: Update root README**

The root README must tell users that persistent storage lives in `backend/`, while `backend_stub/` is only a request-shape stub.

---

### Task 5: Full Verification and Commit

**Files:**
- All files above

- [ ] **Step 1: Run Python compile check**

```bash
python3 -m compileall backend Tests/backend
```

Expected: no syntax errors.

- [ ] **Step 2: Run backend tests**

```bash
python3 -m pytest Tests/backend/test_backend_api.py -q
```

Expected: all backend tests pass.

- [ ] **Step 3: Inspect git diff**

```bash
git status --short
git diff --stat
```

Expected: only backend persistence files, docs, and setup files are changed, plus any pre-existing untracked `GOAL.md` left unstaged.

- [ ] **Step 4: Commit intended changes**

```bash
git add .env.example README.md alembic.ini backend backend_stub/README.md docker-compose.yml docs/superpowers/plans/2026-05-31-healthsync-persistent-backend.md docs/superpowers/specs/2026-05-31-healthsync-persistent-backend-design.md Tests/backend/test_backend_api.py
git commit -m "feat: add persistent HealthSync backend"
```

Expected: commit succeeds without staging unrelated files.

---

## Self-Review

- Spec coverage: the plan covers persistent Postgres storage, Docker/self-hosted setup, managed Postgres setup, upload persistence, read endpoints, token auth, migrations, docs, and tests.
- Placeholder scan: the plan avoids TBD/TODO placeholders and gives exact files and commands.
- Type consistency: the plan consistently uses `device_id`, `export_id`, `metrics`, `workouts`, `UploadResult`, and the existing `/api/apple-health/sync` contract.
