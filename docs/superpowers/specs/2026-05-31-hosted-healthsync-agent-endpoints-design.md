# Hosted HealthSync Agent Endpoints Design

## Goal

Add an opt-in hosted storage mode where HealthSync can save selected Apple Health data into our database and provide the user with a private read-only endpoint plus auth token for AI agents.

## Scope

This design extends the existing FastAPI/Postgres backend. It does not replace the self-hosted backend path. Users should be able to choose either:

- My own backend: current backend URL and token flow.
- Hosted HealthSync storage: our hosted database, workspace-scoped tokens, and a private agent endpoint.

V1 is token-based and account-ready. It avoids full user accounts now, but its data model leaves room to attach workspaces to accounts later.

## Architecture

Use one backend codebase with two modes:

- Self-hosted mode: existing `API_TOKEN` validates upload and read endpoints.
- Hosted mode: workspace-scoped tokens validate ingest and agent reads.

Hosted mode adds:

- `workspace_id`: private container for one user's HealthSync data.
- `device_id`: app/device uploading data.
- `ingest_token`: write-only token stored by the app in Keychain.
- `agent_token`: read-only token copied by the user into their AI agent.

The existing upload endpoint stays stable:

```text
POST /api/apple-health/sync
```

The backend determines whether the bearer token is the self-hosted `API_TOKEN` or a hosted `ingest_token`.

## Data Model

Add `workspaces`:

- `id`
- `created_at`
- `label`

Add `workspace_devices`:

- `workspace_id`
- `device_id`
- `created_at`
- `last_seen_at`
- `label`

Add `access_tokens`:

- `id`
- `workspace_id`
- `token_hash`
- `kind`
- `created_at`
- `last_used_at`
- `revoked_at`

Allowed token kinds:

- `ingest`: app upload only.
- `agent_read`: private agent reads only.

Update existing tables with `workspace_id`:

- `sync_batches.workspace_id`
- `health_metrics.workspace_id`
- `health_workouts.workspace_id`

For hosted data, dedupe metric and workout records by `workspace_id + device_id + id`. For legacy self-hosted data, preserve the current `device_id + id` behavior unless a migration converts self-hosted rows into a default workspace.

## Token Rules

Store only token hashes. Never store raw tokens after provisioning.

Token capabilities:

- Ingest tokens can upload HealthSync payloads.
- Ingest tokens cannot call agent read endpoints.
- Agent tokens can call read-only agent endpoints.
- Agent tokens cannot upload or mutate data.
- Revoked tokens fail for all endpoints.

Token rotation can be added by revoking the old token row and issuing a new token for the same workspace.

## API Shape

Provision hosted storage:

```text
POST /api/hosted/workspaces
```

V1 response returns raw tokens exactly once:

```json
{
  "workspace_id": "wk_...",
  "backend_url": "https://api.example.com",
  "ingest_token": "hs_ingest_...",
  "agent_endpoint": "https://api.example.com/api/agent/health-data",
  "agent_token": "hs_agent_..."
}
```

Hosted upload:

```text
POST /api/apple-health/sync
Authorization: Bearer hs_ingest_...
```

Private agent endpoint:

```text
GET /api/agent/health-data
Authorization: Bearer hs_agent_...
```

Supported query parameters:

```text
type=stepCount
from=2026-05-01T00:00:00Z
to=2026-05-31T23:59:59Z
limit=100
```

Response shape:

```json
{
  "workspace_id": "wk_...",
  "range": {
    "from": "2026-05-01T00:00:00Z",
    "to": "2026-05-31T23:59:59Z"
  },
  "metrics": [],
  "workouts": [],
  "syncs": []
}
```

Also expose focused read-only endpoints:

```text
GET /api/agent/metrics
GET /api/agent/workouts
GET /api/agent/syncs
```

The combined `health-data` endpoint is the default endpoint users paste into agents.

## App Setup UX

Add a storage choice in Settings:

```text
Storage
( ) My own backend
( ) Hosted HealthSync storage
```

For **My own backend**:

- Keep existing backend URL and token fields.
- Keep current Docker/Supabase/Neon/self-hosted behavior.

For **Hosted HealthSync storage**:

- Show explicit consent:
  `Your selected Apple Health data will be uploaded to HealthSync-hosted storage and made available through a private read-only endpoint.`
- Show `Create Hosted Storage`.
- On success, save hosted backend URL, workspace ID, and ingest token.
- Store the ingest token in Keychain.
- Display the agent endpoint and read-only agent token with copy actions.

V1 does not need revoke/regenerate UI, but backend token revocation should be supported so the UI can add it later.

## Data Flow

1. User selects Hosted HealthSync storage.
2. App calls hosted provisioning endpoint.
3. Backend creates workspace, ingest token, and agent read token.
4. App stores hosted backend URL and ingest token in Keychain.
5. App uploads selected Apple Health batches with the ingest token.
6. Backend writes rows under the token's `workspace_id`.
7. User copies private agent endpoint and agent token.
8. Agent calls read-only endpoint and receives only that workspace's data.

## Safety Boundaries

- Hosted mode is opt-in only.
- No automatic migration from self-hosted to hosted.
- No public health-data endpoint without token auth.
- No raw token logging.
- No raw health payload logging.
- Agent token is read-only.
- Ingest token is write-only.
- Production hosted endpoints must use HTTPS.

## Testing

Backend tests should prove:

- Hosted workspace provisioning returns ingest and agent tokens exactly once.
- Raw tokens are not persisted; only hashes are stored.
- Ingest token can upload.
- Ingest token cannot call agent endpoints.
- Agent token can read.
- Agent token cannot upload.
- Self-hosted `API_TOKEN` mode still works.
- Agent endpoint returns only the token's workspace data.
- Duplicate HealthKit records dedupe within `workspace_id + device_id + id`.
- Revoked tokens fail.

App tests should prove:

- Hosted setup stores ingest token in Keychain.
- Hosted setup stores workspace ID locally.
- Hosted setup displays endpoint and read-only token for copy.
- Hosted setup does not print tokens or raw health payloads.

## Rollout

1. Backend:
   - schema migration
   - token hashing and verification
   - hosted provisioning endpoint
   - workspace-scoped persistence
   - private agent read endpoints
2. App:
   - storage mode setting
   - hosted provisioning flow
   - copy endpoint/token UI
3. Skill and docs:
   - update repo-local skill with hosted-storage setup
   - document private agent endpoint usage
