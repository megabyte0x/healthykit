# HealthSync Persistent Backend Design

## Goal

Make it easy for a HealthSync user to set up durable backend storage, sync Apple Health data into it, and fetch that stored data back through documented API endpoints.

## Scope

This design keeps the iOS app's existing upload contract stable and replaces the local-only backend stub with a real FastAPI backend that persists data in Postgres. The same backend supports two setup modes:

- Local or self-hosted: Docker Compose runs the API and Postgres together.
- Managed database: the user creates a Supabase or Neon Postgres database, sets `DATABASE_URL`, and runs the same API.

The first implementation does not add new iOS read screens. It gives the app persistent upload storage immediately and exposes backend fetch APIs that can be used by dashboards, scripts, or a future app UI.

## User Setup Experience

The user should be able to follow one of two paths.

For local or self-hosted setup:

1. Copy `.env.example` to `.env`.
2. Replace `API_TOKEN` with a generated token.
3. Run `docker compose up --build`.
4. Enter `http://127.0.0.1:8080` in the iOS simulator, or the Mac/VPS HTTPS URL on a real device.
5. Enter the same token in HealthSync settings.

For managed Postgres setup:

1. Create a Supabase or Neon Postgres database.
2. Copy the pooled Postgres connection string.
3. Set `DATABASE_URL` and `API_TOKEN` in the backend environment.
4. Run migrations.
5. Deploy or run the API.
6. Enter the deployed API URL and token in HealthSync settings.

## Architecture

The backend is a focused FastAPI service with three layers:

- API layer: authenticates bearer tokens, validates HealthSync payloads, and exposes sync/read endpoints.
- Persistence layer: writes devices, sync batches, metrics, and workouts through SQLAlchemy sessions.
- Schema layer: owns Pydantic request/response models and SQLAlchemy table definitions.

The app continues to call:

```text
POST /api/apple-health/sync
```

The backend adds:

```text
GET /health
GET /api/apple-health/syncs
GET /api/apple-health/metrics
GET /api/apple-health/workouts
```

## Database Model

`devices`

- `device_id` primary key
- `first_seen_at`
- `last_seen_at`
- `app_version`

`sync_batches`

- `export_id` primary key
- `device_id`
- `generated_at`
- `received_at`
- `schema_version`
- `timezone`
- `source`
- `date_range_start`
- `date_range_end`
- `metrics_count`
- `workouts_count`

`health_metrics`

- composite primary key: `device_id`, `id`
- `type`
- `value`
- `unit`
- `start_at`
- `end_at`
- `source_name`
- `source_bundle_id`
- `metadata` JSON/JSONB
- `export_id`

`health_workouts`

- composite primary key: `device_id`, `id`
- `activity_type`
- `start_at`
- `end_at`
- `duration_seconds`
- `total_energy_kcal`
- `active_energy_kcal`
- `distance_meters`
- `source_name`
- `source_bundle_id`
- `metadata` JSON/JSONB
- `export_id`

## Data Flow

1. HealthSync reads Apple Health data on-device.
2. HealthSync stores the batch in local SQLite before upload.
3. HealthSync sends the existing JSON payload with `Authorization: Bearer <token>`.
4. The backend validates the token against `API_TOKEN`.
5. The backend upserts the device and sync batch.
6. The backend inserts or updates metrics and workouts by `device_id + id`.
7. The backend returns `{ "ok": true, "received": n, "duplicates": m }`.
8. HealthSync marks the local batch uploaded only after the backend accepts it.

This keeps retries safe. If the same HealthKit sample is resent, the backend updates the existing row and reports it as a duplicate.

## Error Handling

- Missing bearer token returns `401`.
- Wrong bearer token returns `403`.
- Missing or malformed payload fields return FastAPI validation errors.
- Database connection failures fail fast at request time and are visible in server logs.
- Fetch endpoints require the same bearer token as uploads.
- List endpoints cap `limit` to avoid unbounded reads.

## Documentation

The implementation should include:

- `.env.example`
- `docker-compose.yml`
- `backend/Dockerfile`
- `backend/README.md`
- `backend/requirements.txt`
- migration files
- token generation helper

The README should show exact setup commands for Docker, Supabase, Neon, and real-device testing.

## Testing

Tests should cover:

- token authentication failures
- successful sync persistence
- duplicate sync behavior
- metric fetch filtering
- workout fetch filtering
- sync batch listing

The test database can use SQLite for fast local tests while production and Docker use Postgres.
