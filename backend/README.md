# HealthSync Persistent Backend

This backend stores HealthSync uploads in Postgres and exposes read APIs for synced metrics, workouts, and sync batches.

The iOS app already sends the correct request shape:

```text
POST /api/apple-health/sync
Authorization: Bearer <API_TOKEN>
```

## Local Or Self-Hosted Setup

1. Copy the environment template:

```bash
cp .env.example .env
```

2. Generate two tokens:

```bash
python3 -m backend.scripts.generate_token
python3 -m backend.scripts.generate_token
```

3. In `.env`, replace only these local Docker values: `POSTGRES_PASSWORD`, `API_TOKEN`, and `TOKEN_HASH_SECRET`. Paste the first token as `API_TOKEN`, paste the second token as `TOKEN_HASH_SECRET`, and set `POSTGRES_PASSWORD` to a local database password.

4. Start Postgres and the API:

```bash
docker compose up --build
```

The API runs on:

```text
http://127.0.0.1:8080
```

For an iOS simulator, enter `http://127.0.0.1:8080` in HealthSync settings. For a real iPhone, use an HTTPS URL reachable from the phone, or use your Mac's LAN address for same-Wi-Fi testing.

## Managed Postgres Setup

Use this path for Supabase, Neon, or another hosted Postgres database.

1. Create a Postgres database with your provider.
2. Copy the provider's Postgres connection string.
3. Set environment variables where the API will run:

```bash
export DATABASE_URL='postgresql+psycopg://USER:PASSWORD@HOST:PORT/DATABASE'
export API_TOKEN="$(python3 -m backend.scripts.generate_token)"
export TOKEN_HASH_SECRET="$(python3 -m backend.scripts.generate_token)"
```

4. Install dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
```

5. Run migrations:

```bash
alembic upgrade head
```

6. Start the API:

```bash
uvicorn backend.main:app --host 0.0.0.0 --port 8080
```

For production iPhone sync, deploy this API behind HTTPS and enter the deployed base URL plus `API_TOKEN` in HealthSync settings.

## Hosted Supabase Mode

Use this path when HealthSync should provision separate hosted workspaces with app ingest tokens and private read-only agent tokens. User data is stored in Supabase Postgres through this FastAPI backend. Apps and agents never receive Supabase credentials.

Set the hosted environment:

```bash
export DATABASE_URL='postgresql+psycopg://USER:PASSWORD@HOST:PORT/DATABASE'
export API_TOKEN="$(python3 -m backend.scripts.generate_token)"
export TOKEN_HASH_SECRET="$(python3 -m backend.scripts.generate_token)"
export HOSTED_PUBLIC_BASE_URL='https://api.example.com'
export HOSTED_PROVISIONING_ENABLED=true
```

Run migrations and start the API:

```bash
alembic upgrade head
uvicorn backend.main:app --host 0.0.0.0 --port 8080
```

Provision a workspace:

```bash
curl -X POST "$HOSTED_PUBLIC_BASE_URL/api/hosted/workspaces" \
  -H "Content-Type: application/json" \
  -d '{"label":"Personal Health"}'
```

The response includes `workspace_id`, `backend_url`, `ingest_token`, `agent_endpoint`, and `agent_token`. Configure the iOS app with `backend_url` and `ingest_token`. Save both tokens securely, and give AI agents only `agent_endpoint` and `agent_token`.

Read aggregated health data from the private agent endpoint:

```bash
curl -H "Authorization: Bearer $AGENT_TOKEN" \
  "$HOSTED_PUBLIC_BASE_URL/api/agent/health-data"
```

## Tables

The migration creates:

- `workspaces`
- `workspace_devices`
- `access_tokens`
- `devices`
- `sync_batches`
- `health_metrics`
- `health_workouts`

Metric and workout rows are unique by `workspace_id`, `device_id`, and HealthKit record `id`, so app retries are safe without mixing hosted workspaces.

## API

Health check:

```bash
curl http://127.0.0.1:8080/health
```

List sync batches:

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  "http://127.0.0.1:8080/api/apple-health/syncs?device_id=device-1"
```

List metrics:

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  "http://127.0.0.1:8080/api/apple-health/metrics?device_id=device-1&type=stepCount"
```

List workouts:

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  "http://127.0.0.1:8080/api/apple-health/workouts?device_id=device-1"
```

Agent read endpoint:

```bash
curl -H "Authorization: Bearer $AGENT_TOKEN" \
  "https://api.example.com/api/agent/health-data"
```

Post a minimal sync payload:

```bash
curl -X POST "http://127.0.0.1:8080/api/apple-health/sync" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "device-1",
    "export_id": "11111111-1111-4111-8111-111111111111",
    "generated_at": "2026-05-31T10:00:00.000Z",
    "timezone": "Asia/Kolkata",
    "source": "ios-healthkit",
    "schema_version": 1,
    "date_range": {
      "start": "2026-05-30T10:00:00.000Z",
      "end": "2026-05-31T10:00:00.000Z"
    },
    "metrics": [],
    "workouts": []
  }'
```

## Development Tests

Backend tests use SQLite for fast local verification:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
python3 -m pytest Tests/backend/test_backend_api.py -q
```
