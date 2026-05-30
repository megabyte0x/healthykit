# Hosted HealthSync Agent Endpoints Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add opt-in hosted HealthSync storage backed by Supabase Postgres, with write-only app ingest tokens and read-only private agent endpoints.

**Architecture:** Extend the existing FastAPI/Postgres backend with workspace-scoped hosted mode while preserving the current self-hosted `API_TOKEN` mode. FastAPI remains the only app/agent API boundary; Supabase is used as hosted Postgres storage through the existing SQLAlchemy/Alembic path. The iOS app gains a storage mode setting, hosted provisioning call, Keychain-backed hosted ingest token, and copyable read-only agent endpoint/token.

**Tech Stack:** Python 3.12, FastAPI, SQLAlchemy 2, Alembic, Supabase Postgres, SQLite-backed pytest tests, SwiftUI, XCTest, iOS Keychain.

---

## File Structure

- Modify `backend/config.py`: add hosted settings for public base URL, token hash secret, and hosted provisioning flag.
- Create `backend/tokens.py`: generate prefixed tokens, hash tokens with HMAC-SHA256, and compare hashes.
- Create `backend/auth.py`: resolve self-hosted, hosted ingest, and hosted agent-read auth contexts.
- Modify `backend/models.py`: add `WorkspaceRecord`, `WorkspaceDeviceRecord`, `AccessTokenRecord`; add `workspace_id` to sync/metric/workout rows.
- Modify `backend/schemas.py`: add hosted provisioning and agent response schemas.
- Modify `backend/repository.py`: persist and read records by workspace; provision workspaces and access tokens.
- Modify `backend/app.py`: split auth dependencies, add hosted provisioning, add agent endpoints.
- Create `backend/alembic/versions/20260531_0002_hosted_workspaces.py`: Supabase-compatible migration.
- Modify `Tests/backend/test_backend_api.py`: keep existing tests and add hosted tests.
- Modify `backend/README.md`, `.env.example`, and `.codex/skills/healthsync-backend-setup/*`: document Supabase hosted mode.
- Modify `HealthSync/AppSettings.swift`: add storage mode and hosted metadata fields.
- Modify `HealthSync/Services/KeychainStore.swift`: support named token accounts.
- Modify `HealthSync/Services/APIClient.swift`: add hosted provisioning request/response.
- Modify `HealthSync/AppState.swift`: use storage mode, call hosted provisioning, and choose the right upload token.
- Modify `HealthSync/Views/SettingsView.swift`: add storage picker, consent text, hosted setup button, and copy actions.
- Modify `Tests/HealthSyncTests/APIClientTests.swift` and `Tests/HealthSyncTests/LocalStoreTests.swift`: cover hosted request construction and settings persistence.

---

### Task 1: Backend Token And Hosted Auth Tests

**Files:**
- Modify: `Tests/backend/test_backend_api.py`
- Create: `backend/tokens.py`
- Create: `backend/auth.py`
- Modify: `backend/config.py`

- [ ] **Step 1: Add failing hosted auth tests**

Append these tests to `Tests/backend/test_backend_api.py`:

```python
def test_hosted_provisioning_returns_tokens_and_stores_hashes(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)

    response = client.post("/api/hosted/workspaces", json={"label": "Personal Health"})

    assert response.status_code == 200
    body = response.json()
    assert body["workspace_id"].startswith("wk_")
    assert body["backend_url"] == "https://healthsync.example.test"
    assert body["ingest_token"].startswith("hs_ingest_")
    assert body["agent_token"].startswith("hs_agent_")
    assert body["agent_endpoint"] == "https://healthsync.example.test/api/agent/health-data"

    with client.app.state.session_factory() as db:
        from backend.models import AccessTokenRecord

        tokens = db.query(AccessTokenRecord).all()
        assert len(tokens) == 2
        assert {token.kind for token in tokens} == {"ingest", "agent_read"}
        assert all(not token.token_hash.startswith("hs_") for token in tokens)
        assert all(body["ingest_token"] != token.token_hash for token in tokens)
        assert all(body["agent_token"] != token.token_hash for token in tokens)


def test_hosted_provisioning_can_be_disabled(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=False)

    response = client.post("/api/hosted/workspaces", json={"label": "Personal Health"})

    assert response.status_code == 404
```

Update the test helper signature at the top of the same file:

```python
def make_client(tmp_path: Path, hosted: bool = False) -> TestClient:
    database_url = f"sqlite+pysqlite:///{tmp_path / 'healthsync.sqlite'}"
    engine = create_engine_for_url(database_url)
    Base.metadata.create_all(engine)
    session_factory = create_session_factory(engine)
    app = create_app(
        Settings(
            database_url=database_url,
            api_token="test-token",
            token_hash_secret="test-hash-secret",
            hosted_public_base_url="https://healthsync.example.test",
            hosted_provisioning_enabled=hosted,
        ),
        session_factory=session_factory,
    )
    app.state.session_factory = session_factory
    return TestClient(app)
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
.venv/bin/python -m pytest Tests/backend/test_backend_api.py -q
```

Expected: failure because `Settings` does not accept hosted fields and hosted models/routes do not exist.

- [ ] **Step 3: Implement token helpers**

Create `backend/tokens.py`:

```python
from __future__ import annotations

import hashlib
import hmac
import secrets


def generate_token(prefix: str) -> str:
    return f"{prefix}_{secrets.token_urlsafe(32)}"


def token_hash(token: str, secret: str) -> str:
    return hmac.new(secret.encode("utf-8"), token.encode("utf-8"), hashlib.sha256).hexdigest()


def token_hash_matches(token: str, stored_hash: str, secret: str) -> bool:
    candidate = token_hash(token, secret)
    return hmac.compare_digest(candidate.encode("utf-8"), stored_hash.encode("utf-8"))
```

- [ ] **Step 4: Extend settings**

Modify `backend/config.py`:

```python
@dataclass(frozen=True)
class Settings:
    database_url: str
    api_token: str
    token_hash_secret: str
    hosted_public_base_url: str
    hosted_provisioning_enabled: bool = False
    self_hosted_workspace_id: str = "self_hosted"
    default_page_size: int = 100
    max_page_size: int = 500

    @classmethod
    def from_env(cls) -> "Settings":
        database_url = os.environ.get("DATABASE_URL", "").strip()
        api_token = os.environ.get("API_TOKEN", "").strip()
        token_hash_secret = os.environ.get("TOKEN_HASH_SECRET", "").strip()
        hosted_public_base_url = os.environ.get("HOSTED_PUBLIC_BASE_URL", "").strip()
        hosted_provisioning_enabled = os.environ.get("HOSTED_PROVISIONING_ENABLED", "").lower() == "true"
        if not database_url:
            raise RuntimeError("DATABASE_URL is required.")
        if not api_token:
            raise RuntimeError("API_TOKEN is required.")
        if not token_hash_secret:
            raise RuntimeError("TOKEN_HASH_SECRET is required.")
        if hosted_provisioning_enabled and not hosted_public_base_url:
            raise RuntimeError("HOSTED_PUBLIC_BASE_URL is required when hosted provisioning is enabled.")
        return cls(
            database_url=database_url,
            api_token=api_token,
            token_hash_secret=token_hash_secret,
            hosted_public_base_url=hosted_public_base_url.rstrip("/"),
            hosted_provisioning_enabled=hosted_provisioning_enabled,
        )
```

- [ ] **Step 5: Run tests**

Run:

```bash
.venv/bin/python -m pytest Tests/backend/test_backend_api.py -q
```

Expected: existing tests fail until test helper passes new settings fields; hosted tests fail until models/routes are implemented.

- [ ] **Step 6: Commit**

```bash
git add Tests/backend/test_backend_api.py backend/tokens.py backend/config.py
git commit -m "test: cover hosted token provisioning"
```

---

### Task 2: Hosted Schema And Migration

**Files:**
- Modify: `backend/models.py`
- Create: `backend/alembic/versions/20260531_0002_hosted_workspaces.py`
- Modify: `Tests/backend/test_backend_api.py`

- [ ] **Step 1: Add model tests for workspace-scoped rows**

Append this test:

```python
def test_hosted_sync_rows_are_workspace_scoped(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)
    provisioned = client.post("/api/hosted/workspaces", json={"label": "Personal Health"}).json()
    headers = {"Authorization": f"Bearer {provisioned['ingest_token']}", "X-App-Version": "1.0"}

    response = client.post("/api/apple-health/sync", headers=headers, json=sample_payload())

    assert response.status_code == 200
    with client.app.state.session_factory() as db:
        from backend.models import HealthMetricRecord, HealthWorkoutRecord, SyncBatchRecord

        batch = db.query(SyncBatchRecord).one()
        metric = db.query(HealthMetricRecord).one()
        workout = db.query(HealthWorkoutRecord).one()
        assert batch.workspace_id == provisioned["workspace_id"]
        assert metric.workspace_id == provisioned["workspace_id"]
        assert workout.workspace_id == provisioned["workspace_id"]
```

- [ ] **Step 2: Run test to verify failure**

```bash
.venv/bin/python -m pytest Tests/backend/test_backend_api.py::test_hosted_sync_rows_are_workspace_scoped -q
```

Expected: fails because workspace models/columns are missing.

- [ ] **Step 3: Update models**

Add these models to `backend/models.py`:

```python
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
    device_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    label: Mapped[str | None] = mapped_column(String(128), nullable=True)


class AccessTokenRecord(Base):
    __tablename__ = "access_tokens"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    workspace_id: Mapped[str] = mapped_column(String(64), ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False)
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False, unique=True, index=True)
    kind: Mapped[str] = mapped_column(String(32), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
```

Add `workspace_id` to `SyncBatchRecord`, `HealthMetricRecord`, and `HealthWorkoutRecord`. Change metric and workout primary keys to include `workspace_id`:

```python
workspace_id: Mapped[str] = mapped_column(
    String(64),
    ForeignKey("workspaces.id", ondelete="CASCADE"),
    primary_key=True,
    default="self_hosted",
)
```

For `SyncBatchRecord`, use:

```python
workspace_id: Mapped[str] = mapped_column(
    String(64),
    ForeignKey("workspaces.id", ondelete="CASCADE"),
    nullable=False,
    default="self_hosted",
    index=True,
)
```

- [ ] **Step 4: Add migration**

Create `backend/alembic/versions/20260531_0002_hosted_workspaces.py` with:

```python
from __future__ import annotations

from collections.abc import Sequence
from datetime import datetime, timezone

from alembic import op
import sqlalchemy as sa

revision: str = "20260531_0002"
down_revision: str | None = "20260531_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "workspaces",
        sa.Column("id", sa.String(length=64), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("label", sa.String(length=128), nullable=True),
    )
    op.bulk_insert(
        sa.table(
            "workspaces",
            sa.column("id", sa.String),
            sa.column("created_at", sa.DateTime(timezone=True)),
            sa.column("label", sa.String),
        ),
        [{"id": "self_hosted", "created_at": datetime.now(timezone.utc), "label": "Self-hosted"}],
    )
    op.create_table(
        "workspace_devices",
        sa.Column("workspace_id", sa.String(length=64), sa.ForeignKey("workspaces.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("device_id", sa.String(length=128), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("label", sa.String(length=128), nullable=True),
    )
    op.create_table(
        "access_tokens",
        sa.Column("id", sa.String(length=64), primary_key=True),
        sa.Column("workspace_id", sa.String(length=64), sa.ForeignKey("workspaces.id", ondelete="CASCADE"), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("kind", sa.String(length=32), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_access_tokens_token_hash", "access_tokens", ["token_hash"], unique=True)
    op.add_column("sync_batches", sa.Column("workspace_id", sa.String(length=64), nullable=False, server_default="self_hosted"))
    op.add_column("health_metrics", sa.Column("workspace_id", sa.String(length=64), nullable=False, server_default="self_hosted"))
    op.add_column("health_workouts", sa.Column("workspace_id", sa.String(length=64), nullable=False, server_default="self_hosted"))
    op.create_index("ix_sync_batches_workspace_received", "sync_batches", ["workspace_id", "received_at"])
    op.create_index("ix_health_metrics_workspace_type_start", "health_metrics", ["workspace_id", "type", "start_at"])
    op.create_index("ix_health_workouts_workspace_activity_start", "health_workouts", ["workspace_id", "activity_type", "start_at"])


def downgrade() -> None:
    op.drop_index("ix_health_workouts_workspace_activity_start", table_name="health_workouts")
    op.drop_index("ix_health_metrics_workspace_type_start", table_name="health_metrics")
    op.drop_index("ix_sync_batches_workspace_received", table_name="sync_batches")
    op.drop_column("health_workouts", "workspace_id")
    op.drop_column("health_metrics", "workspace_id")
    op.drop_column("sync_batches", "workspace_id")
    op.drop_index("ix_access_tokens_token_hash", table_name="access_tokens")
    op.drop_table("access_tokens")
    op.drop_table("workspace_devices")
    op.drop_table("workspaces")
```

- [ ] **Step 5: Run migration smoke test**

```bash
env DATABASE_URL=sqlite+pysqlite:////private/tmp/healthsync-hosted-plan.sqlite .venv/bin/alembic upgrade head
```

Expected: migrations `20260531_0001` and `20260531_0002` run successfully.

- [ ] **Step 6: Commit**

```bash
git add backend/models.py backend/alembic/versions/20260531_0002_hosted_workspaces.py Tests/backend/test_backend_api.py
git commit -m "feat: add hosted workspace schema"
```

---

### Task 3: Workspace Provisioning And Hosted Upload Auth

**Files:**
- Modify: `backend/auth.py`
- Modify: `backend/repository.py`
- Modify: `backend/schemas.py`
- Modify: `backend/app.py`
- Modify: `Tests/backend/test_backend_api.py`

- [ ] **Step 1: Add failing token capability tests**

Append:

```python
def test_hosted_token_capabilities_are_separated(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)
    provisioned = client.post("/api/hosted/workspaces", json={"label": "Personal Health"}).json()
    ingest_headers = {"Authorization": f"Bearer {provisioned['ingest_token']}"}
    agent_headers = {"Authorization": f"Bearer {provisioned['agent_token']}"}

    upload = client.post("/api/apple-health/sync", headers=ingest_headers, json=sample_payload())
    assert upload.status_code == 200

    ingest_read = client.get("/api/agent/metrics", headers=ingest_headers)
    assert ingest_read.status_code == 403

    agent_upload = client.post("/api/apple-health/sync", headers=agent_headers, json=sample_payload("22222222-2222-4222-8222-222222222222"))
    assert agent_upload.status_code == 403

    agent_read = client.get("/api/agent/metrics", headers=agent_headers)
    assert agent_read.status_code == 200
```

- [ ] **Step 2: Run test to verify failure**

```bash
.venv/bin/python -m pytest Tests/backend/test_backend_api.py::test_hosted_token_capabilities_are_separated -q
```

Expected: fails because provisioning/auth/agent routes do not exist.

- [ ] **Step 3: Add schemas**

Add to `backend/schemas.py`:

```python
class HostedWorkspaceCreate(BaseModel):
    label: str | None = None


class HostedWorkspaceResponse(BaseModel):
    workspace_id: str
    backend_url: str
    ingest_token: str
    agent_endpoint: str
    agent_token: str
```

- [ ] **Step 4: Add auth context**

Create `backend/auth.py`:

```python
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import secrets

from fastapi import Header, HTTPException, status
from sqlalchemy.orm import Session

from .config import Settings
from .models import AccessTokenRecord
from .tokens import token_hash


@dataclass(frozen=True)
class AuthContext:
    workspace_id: str
    token_kind: str
    self_hosted: bool = False


def bearer_token(authorization: str | None) -> str:
    if authorization is None or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    return authorization.removeprefix("Bearer ").strip()


def resolve_sync_auth(db: Session, settings: Settings, authorization: str | None = Header(default=None)) -> AuthContext:
    token = bearer_token(authorization)
    if secrets.compare_digest(token.encode("utf-8"), settings.api_token.encode("utf-8")):
        return AuthContext(workspace_id=settings.self_hosted_workspace_id, token_kind="self_hosted", self_hosted=True)
    return resolve_access_token(db, settings, token, required_kind="ingest")


def resolve_agent_auth(db: Session, settings: Settings, authorization: str | None = Header(default=None)) -> AuthContext:
    token = bearer_token(authorization)
    return resolve_access_token(db, settings, token, required_kind="agent_read")


def resolve_access_token(db: Session, settings: Settings, token: str, required_kind: str) -> AuthContext:
    digest = token_hash(token, settings.token_hash_secret)
    record = db.query(AccessTokenRecord).filter(AccessTokenRecord.token_hash == digest).one_or_none()
    if record is None or record.revoked_at is not None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid bearer token")
    if record.kind != required_kind:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Token is not allowed for this endpoint")
    record.last_used_at = datetime.now(timezone.utc)
    db.commit()
    return AuthContext(workspace_id=record.workspace_id, token_kind=record.kind)
```

- [ ] **Step 5: Add provisioning repository function**

Add to `backend/repository.py`:

```python
def provision_hosted_workspace(db: Session, settings: Settings, label: str | None) -> HostedWorkspaceResponse:
    now = datetime.now(timezone.utc)
    workspace_id = f"wk_{secrets.token_urlsafe(18)}"
    ingest_token = generate_token("hs_ingest")
    agent_token = generate_token("hs_agent")
    db.add(WorkspaceRecord(id=workspace_id, created_at=now, label=label))
    db.add(
        AccessTokenRecord(
            id=f"tok_{secrets.token_urlsafe(18)}",
            workspace_id=workspace_id,
            token_hash=token_hash(ingest_token, settings.token_hash_secret),
            kind="ingest",
            created_at=now,
        )
    )
    db.add(
        AccessTokenRecord(
            id=f"tok_{secrets.token_urlsafe(18)}",
            workspace_id=workspace_id,
            token_hash=token_hash(agent_token, settings.token_hash_secret),
            kind="agent_read",
            created_at=now,
        )
    )
    db.commit()
    return HostedWorkspaceResponse(
        workspace_id=workspace_id,
        backend_url=settings.hosted_public_base_url,
        ingest_token=ingest_token,
        agent_endpoint=f"{settings.hosted_public_base_url}/api/agent/health-data",
        agent_token=agent_token,
    )
```

Import `secrets`, `Settings`, `HostedWorkspaceResponse`, `WorkspaceRecord`, `AccessTokenRecord`, `generate_token`, and `token_hash`.

- [ ] **Step 6: Pass workspace ID into persistence**

Change `persist_sync_payload` signature:

```python
def persist_sync_payload(db: Session, payload: SyncPayloadIn, app_version: str | None, workspace_id: str) -> UploadResult:
```

Use `workspace_id` when loading/creating batch, metric, and workout records:

```python
record = db.get(HealthMetricRecord, (workspace_id, payload.device_id, metric.id))
```

Create or update `WorkspaceDeviceRecord` for hosted and self-hosted contexts:

```python
device = db.get(WorkspaceDeviceRecord, (workspace_id, payload.device_id))
if device is None:
    db.add(WorkspaceDeviceRecord(workspace_id=workspace_id, device_id=payload.device_id, created_at=received_at, last_seen_at=received_at))
else:
    device.last_seen_at = received_at
```

- [ ] **Step 7: Wire routes**

In `backend/app.py`, replace `require_token` with dependencies that call `resolve_sync_auth` and `resolve_agent_auth`. Add:

```python
@app.post("/api/hosted/workspaces", response_model=HostedWorkspaceResponse)
def create_hosted_workspace(
    request: HostedWorkspaceCreate,
    db: Session = Depends(get_db),
) -> HostedWorkspaceResponse:
    if not settings.hosted_provisioning_enabled:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Hosted provisioning is disabled")
    return provision_hosted_workspace(db, settings, request.label)
```

Change upload route to:

```python
auth: AuthContext = Depends(get_sync_auth)
return persist_sync_payload(db, payload, x_app_version, auth.workspace_id)
```

- [ ] **Step 8: Run tests**

```bash
.venv/bin/python -m pytest Tests/backend/test_backend_api.py -q
```

Expected: hosted provisioning, hosted upload, and legacy self-hosted tests pass.

- [ ] **Step 9: Commit**

```bash
git add backend/auth.py backend/app.py backend/repository.py backend/schemas.py Tests/backend/test_backend_api.py
git commit -m "feat: provision hosted workspaces"
```

---

### Task 4: Private Agent Read Endpoints

**Files:**
- Modify: `backend/repository.py`
- Modify: `backend/schemas.py`
- Modify: `backend/app.py`
- Modify: `Tests/backend/test_backend_api.py`

- [ ] **Step 1: Add failing workspace isolation test**

Append:

```python
def test_agent_endpoint_returns_only_own_workspace_data(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)
    first = client.post("/api/hosted/workspaces", json={"label": "First"}).json()
    second = client.post("/api/hosted/workspaces", json={"label": "Second"}).json()

    client.post("/api/apple-health/sync", headers={"Authorization": f"Bearer {first['ingest_token']}"}, json=sample_payload())
    client.post(
        "/api/apple-health/sync",
        headers={"Authorization": f"Bearer {second['ingest_token']}"},
        json=sample_payload("22222222-2222-4222-8222-222222222222"),
    )

    response = client.get("/api/agent/health-data", headers={"Authorization": f"Bearer {first['agent_token']}"})

    assert response.status_code == 200
    body = response.json()
    assert body["workspace_id"] == first["workspace_id"]
    assert [item["export_id"] for item in body["syncs"]] == ["11111111-1111-4111-8111-111111111111"]
```

- [ ] **Step 2: Run test to verify failure**

```bash
.venv/bin/python -m pytest Tests/backend/test_backend_api.py::test_agent_endpoint_returns_only_own_workspace_data -q
```

Expected: fails because `/api/agent/health-data` is not implemented.

- [ ] **Step 3: Add agent schemas**

Add:

```python
class AgentRange(BaseModel):
    from_at: datetime | None = Field(default=None, alias="from")
    to: datetime | None = None


class AgentHealthDataResponse(BaseModel):
    workspace_id: str
    range: AgentRange
    metrics: list[HealthMetricOut]
    workouts: list[HealthWorkoutOut]
    syncs: list[SyncBatchOut]
```

- [ ] **Step 4: Scope list functions by workspace**

Add `workspace_id: str | None = None` to `list_metrics`, `list_workouts`, and `list_sync_batches`, and filter with:

```python
if workspace_id:
    stmt = stmt.where(HealthMetricRecord.workspace_id == workspace_id)
```

Use the matching model in each function.

- [ ] **Step 5: Add agent routes**

In `backend/app.py`, add:

```python
@app.get("/api/agent/metrics", response_model=MetricListResponse)
def agent_metrics(
    auth: AuthContext = Depends(get_agent_auth),
    db: Session = Depends(get_db),
    metric_type: str | None = Query(default=None, alias="type"),
    start_at: datetime | None = Query(default=None, alias="from"),
    end_at: datetime | None = Query(default=None, alias="to"),
    limit: int = Query(default=settings.default_page_size, ge=1, le=settings.max_page_size),
    offset: int = Query(default=0, ge=0),
) -> MetricListResponse:
    return list_metrics(db, workspace_id=auth.workspace_id, metric_type=metric_type, start_at=start_at, end_at=end_at, limit=limit, offset=offset)
```

Add equivalent `/api/agent/workouts`, `/api/agent/syncs`, and combined `/api/agent/health-data`.

- [ ] **Step 6: Run tests**

```bash
.venv/bin/python -m pytest Tests/backend/test_backend_api.py -q
```

Expected: all backend tests pass.

- [ ] **Step 7: Commit**

```bash
git add backend/app.py backend/repository.py backend/schemas.py Tests/backend/test_backend_api.py
git commit -m "feat: add private agent read endpoints"
```

---

### Task 5: iOS Hosted Storage Settings And Provisioning Client

**Files:**
- Modify: `HealthSync/AppSettings.swift`
- Modify: `HealthSync/Services/KeychainStore.swift`
- Modify: `HealthSync/Services/APIClient.swift`
- Modify: `HealthSync/AppState.swift`
- Modify: `Tests/HealthSyncTests/APIClientTests.swift`
- Modify: `Tests/HealthSyncTests/LocalStoreTests.swift`

- [ ] **Step 1: Add failing Swift tests**

Add to `Tests/HealthSyncTests/APIClientTests.swift`:

```swift
func testClientBuildsHostedProvisioningRequest() throws {
    let request = try APIClient.makeHostedWorkspaceRequest(
        baseURL: "https://api.example.com",
        label: "Personal Health"
    )

    XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/api/hosted/workspaces")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    XCTAssertEqual(String(data: request.httpBody ?? Data(), encoding: .utf8), #"{"label":"Personal Health"}"#)
}
```

Add to `Tests/HealthSyncTests/LocalStoreTests.swift`:

```swift
func testSettingsPersistHostedStorageMode() async throws {
    let store = try SQLiteLocalStore(url: temporaryDatabaseURL())
    var settings = AppSettings.default
    settings.storageMode = .hostedHealthSync
    settings.hostedWorkspaceID = "wk_test"
    settings.hostedAgentEndpoint = "https://api.example.com/api/agent/health-data"

    try await store.saveSettings(settings)
    let loaded = try await store.loadSettings()

    XCTAssertEqual(loaded.storageMode, .hostedHealthSync)
    XCTAssertEqual(loaded.hostedWorkspaceID, "wk_test")
    XCTAssertEqual(loaded.hostedAgentEndpoint, "https://api.example.com/api/agent/health-data")
}
```

- [ ] **Step 2: Run Swift test build to verify failure**

```bash
xcodebuild build-for-testing -project HealthSync.xcodeproj -scheme HealthSync -destination 'generic/platform=iOS Simulator' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO
```

Expected: fails because `storageMode`, hosted fields, and hosted request builder do not exist.

- [ ] **Step 3: Extend settings**

Modify `HealthSync/AppSettings.swift`:

```swift
enum StorageMode: String, CaseIterable, Codable, Identifiable {
    case customBackend
    case hostedHealthSync

    var id: String { rawValue }

    var label: String {
        switch self {
        case .customBackend: "My own backend"
        case .hostedHealthSync: "Hosted HealthSync storage"
        }
    }
}
```

Add fields to `AppSettings`:

```swift
var storageMode: StorageMode
var hostedWorkspaceID: String?
var hostedAgentEndpoint: String?
```

Set defaults:

```swift
storageMode: .customBackend,
hostedWorkspaceID: nil,
hostedAgentEndpoint: nil,
```

- [ ] **Step 4: Add named Keychain accounts**

Modify `KeychainStore` so existing `readToken`, `saveToken`, and `deleteToken` use a private `account` parameter. Add:

```swift
func readHostedIngestToken() throws -> String? {
    try readToken(account: "hostedIngestToken")
}

func saveHostedIngestToken(_ token: String) throws {
    try saveToken(token, account: "hostedIngestToken")
}

func readHostedAgentToken() throws -> String? {
    try readToken(account: "hostedAgentToken")
}

func saveHostedAgentToken(_ token: String) throws {
    try saveToken(token, account: "hostedAgentToken")
}
```

- [ ] **Step 5: Add provisioning request/response**

Add to `HealthSync/Services/APIClient.swift`:

```swift
struct HostedWorkspaceProvisioningResponse: Codable, Equatable {
    let workspaceID: String
    let backendURL: String
    let ingestToken: String
    let agentEndpoint: String
    let agentToken: String

    enum CodingKeys: String, CodingKey {
        case workspaceID = "workspace_id"
        case backendURL = "backend_url"
        case ingestToken = "ingest_token"
        case agentEndpoint = "agent_endpoint"
        case agentToken = "agent_token"
    }
}

struct HostedWorkspaceProvisioningRequest: Codable {
    let label: String?
}
```

Add static request builder:

```swift
static func makeHostedWorkspaceRequest(baseURL: String, label: String?) throws -> URLRequest {
    let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedURL.isEmpty else { throw APIClientError.missingBackendURL }
    guard let rootURL = URL(string: trimmedURL), let scheme = rootURL.scheme?.lowercased(), ["http", "https"].contains(scheme), rootURL.host != nil else {
        throw APIClientError.invalidBackendURL
    }
    var request = URLRequest(url: rootURL.appendingPathComponent("api").appendingPathComponent("hosted").appendingPathComponent("workspaces"))
    request.httpMethod = "POST"
    request.timeoutInterval = 20
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(HostedWorkspaceProvisioningRequest(label: label))
    return request
}
```

Add async method:

```swift
func provisionHostedWorkspace(baseURL: String, label: String?) async throws -> HostedWorkspaceProvisioningResponse {
    let request = try Self.makeHostedWorkspaceRequest(baseURL: baseURL, label: label)
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else { throw APIClientError.invalidResponse }
    guard Self.classify(statusCode: httpResponse.statusCode) == .accepted else {
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 { throw APIClientError.authRejected }
        throw APIClientError.serverRejected(httpResponse.statusCode)
    }
    return try JSONDecoder().decode(HostedWorkspaceProvisioningResponse.self, from: data)
}
```

- [ ] **Step 6: Update AppState**

Add published fields:

```swift
@Published var hostedAgentToken = ""
```

Add:

```swift
func createHostedStorage() async {
    await runBusy {
        let response = try await APIClient(maxAttempts: 1).provisionHostedWorkspace(
            baseURL: settings.backendURL,
            label: "Personal Health"
        )
        settings.storageMode = .hostedHealthSync
        settings.backendURL = response.backendURL
        settings.hostedWorkspaceID = response.workspaceID
        settings.hostedAgentEndpoint = response.agentEndpoint
        try keychain.saveHostedIngestToken(response.ingestToken)
        try keychain.saveHostedAgentToken(response.agentToken)
        hostedAgentToken = response.agentToken
        try await saveSettingsOnly()
    }
}
```

Update `uploadConfiguration()`:

```swift
let token: String?
switch settings.storageMode {
case .customBackend:
    token = try keychain.readToken()
case .hostedHealthSync:
    token = try keychain.readHostedIngestToken()
}
```

- [ ] **Step 7: Run Swift build**

```bash
xcodebuild build-for-testing -project HealthSync.xcodeproj -scheme HealthSync -destination 'generic/platform=iOS Simulator' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

- [ ] **Step 8: Commit**

```bash
git add HealthSync/AppSettings.swift HealthSync/Services/KeychainStore.swift HealthSync/Services/APIClient.swift HealthSync/AppState.swift Tests/HealthSyncTests/APIClientTests.swift Tests/HealthSyncTests/LocalStoreTests.swift
git commit -m "feat: add hosted storage app provisioning"
```

---

### Task 6: Hosted Settings UI

**Files:**
- Modify: `HealthSync/Views/SettingsView.swift`
- Modify: `Tests/HealthSyncTests/APIClientTests.swift`

- [ ] **Step 1: Add view-facing state assumptions**

No snapshot framework exists in this repo. Validate this task through build and by keeping controls bound to `AppState` fields introduced in Task 5.

- [ ] **Step 2: Update SettingsView**

In `SettingsView`, add a `Storage` section above `Backend`:

```swift
Section("Storage") {
    Picker("Storage", selection: $appState.settings.storageMode) {
        ForEach(StorageMode.allCases) { mode in
            Text(mode.label).tag(mode)
        }
    }

    if appState.settings.storageMode == .hostedHealthSync {
        Text("Your selected Apple Health data will be uploaded to HealthSync-hosted storage and made available through a private read-only endpoint.")
            .font(.footnote)
            .foregroundStyle(.secondary)

        Button {
            Task { await appState.createHostedStorage() }
        } label: {
            Label("Create Hosted Storage", systemImage: "externaldrive.badge.plus")
        }
    }
}
```

In the backend section, keep the backend URL field visible for both modes so development and staging hosted URLs can be entered.

Add agent endpoint/token display under hosted mode:

```swift
if appState.settings.storageMode == .hostedHealthSync {
    Section("Agent Access") {
        if let endpoint = appState.settings.hostedAgentEndpoint, !endpoint.isEmpty {
            Button {
                UIPasteboard.general.string = endpoint
            } label: {
                Label("Copy agent endpoint", systemImage: "doc.on.doc")
            }

            Text(endpoint)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }

        if !appState.hostedAgentToken.isEmpty {
            Button {
                UIPasteboard.general.string = appState.hostedAgentToken
            } label: {
                Label("Copy read-only agent token", systemImage: "key")
            }
        }
    }
}
```

- [ ] **Step 3: Run Swift build**

```bash
xcodebuild build-for-testing -project HealthSync.xcodeproj -scheme HealthSync -destination 'generic/platform=iOS Simulator' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds and no token appears in compile output.

- [ ] **Step 4: Commit**

```bash
git add HealthSync/Views/SettingsView.swift
git commit -m "feat: add hosted storage settings UI"
```

---

### Task 7: Skill And Docs Update

**Files:**
- Modify: `.codex/skills/healthsync-backend-setup/SKILL.md`
- Modify: `.codex/skills/healthsync-backend-setup/references/healthsync-backend.md`
- Modify: `backend/README.md`
- Modify: `README.md`

- [ ] **Step 1: Update repo skill triggers**

In `.codex/skills/healthsync-backend-setup/SKILL.md`, update the description to include Supabase-hosted storage and private agent endpoints:

```yaml
description: Set up, verify, or explain persistent backend storage for the HealthSync iOS app. Use when a user asks an AI agent to make HealthSync data persistent, configure Supabase-hosted storage, configure Docker/Postgres, run migrations, generate ingest or agent tokens, save Apple Health sync data, expose private authenticated agent endpoints, or troubleshoot the HealthSync backend setup.
```

- [ ] **Step 2: Update reference**

In `.codex/skills/healthsync-backend-setup/references/healthsync-backend.md`, add this section:

````markdown
## Hosted Supabase Mode

Hosted mode stores user data in Supabase Postgres through the FastAPI backend. Apps and agents never receive Supabase credentials.

Required hosted env vars:

```text
DATABASE_URL=postgresql+psycopg://USER:PASSWORD@HOST:PORT/DATABASE
API_TOKEN=<self-hosted-admin-token>
TOKEN_HASH_SECRET=<long-random-hmac-secret>
HOSTED_PUBLIC_BASE_URL=https://api.example.com
HOSTED_PROVISIONING_ENABLED=true
```

Provision a workspace:

```bash
curl -X POST "$HOSTED_PUBLIC_BASE_URL/api/hosted/workspaces" \
  -H "Content-Type: application/json" \
  -d '{"label":"Personal Health"}'
```
````

- [ ] **Step 3: Update backend README**

Add a "Hosted Supabase mode" section with:

```bash
export DATABASE_URL='postgresql+psycopg://USER:PASSWORD@HOST:PORT/DATABASE'
export API_TOKEN="$(python3 -m backend.scripts.generate_token)"
export TOKEN_HASH_SECRET="$(python3 -m backend.scripts.generate_token)"
export HOSTED_PUBLIC_BASE_URL='https://api.example.com'
export HOSTED_PROVISIONING_ENABLED=true
alembic upgrade head
uvicorn backend.main:app --host 0.0.0.0 --port 8080
```

- [ ] **Step 4: Validate skill**

```bash
python3 /Users/megabyte0x/.codex/skills/.system/skill-creator/scripts/quick_validate.py .codex/skills/healthsync-backend-setup
```

Expected: `Skill is valid!`

- [ ] **Step 5: Commit**

```bash
git add .codex/skills/healthsync-backend-setup README.md backend/README.md
git commit -m "docs: document hosted Supabase agent setup"
```

---

### Task 8: Full Verification

**Files:**
- All touched files

- [ ] **Step 1: Run backend tests**

```bash
.venv/bin/python -m pytest Tests/backend/test_backend_api.py -q
```

Expected: all backend tests pass.

- [ ] **Step 2: Run backend compile**

```bash
.venv/bin/python -m compileall backend Tests/backend
```

Expected: no syntax errors.

- [ ] **Step 3: Run migration smoke**

```bash
env DATABASE_URL=sqlite+pysqlite:////private/tmp/healthsync-hosted-final.sqlite .venv/bin/alembic upgrade head
```

Expected: migrations run through hosted workspace migration.

- [ ] **Step 4: Validate Compose config**

```bash
docker compose --env-file .env.example config
```

Expected: valid Compose config.

- [ ] **Step 5: Build Swift tests**

```bash
xcodebuild build-for-testing -project HealthSync.xcodeproj -scheme HealthSync -destination 'generic/platform=iOS Simulator' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

- [ ] **Step 6: Validate repo skill**

```bash
python3 /Users/megabyte0x/.codex/skills/.system/skill-creator/scripts/quick_validate.py .codex/skills/healthsync-backend-setup
```

Expected: `Skill is valid!`

- [ ] **Step 7: Inspect final diff**

```bash
git status --short
git log --oneline --decorate -8
```

Expected: only pre-existing untracked `GOAL.md` remains unstaged.

---

## Self-Review

- Spec coverage: this plan covers Supabase hosted storage, workspace provisioning, token hashing, ingest vs agent token capabilities, workspace-scoped writes, private agent endpoints, app hosted setup, Keychain storage, docs, repo skill updates, and verification.
- Completeness scan: the plan uses exact file paths, concrete commands, and concrete snippets. It contains no incomplete sections.
- Type consistency: backend names are consistent across tasks: `workspace_id`, `WorkspaceRecord`, `AccessTokenRecord`, `HostedWorkspaceResponse`, `AuthContext`, `ingest`, `agent_read`, and `AgentHealthDataResponse`. iOS names are consistent: `StorageMode`, `hostedWorkspaceID`, `hostedAgentEndpoint`, `HostedWorkspaceProvisioningResponse`, and `createHostedStorage()`.
