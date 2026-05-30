# HealthSync Backend Reference

## Expected Files

For an implementation repo, expect or create:

- `backend/app.py`: FastAPI routes and auth dependency.
- `backend/config.py`: `DATABASE_URL` and `API_TOKEN` settings.
- `backend/database.py`: SQLAlchemy engine and session helpers.
- `backend/models.py`: devices, sync batches, metrics, workouts.
- `backend/schemas.py`: Pydantic payload and response models.
- `backend/repository.py`: persistence and fetch queries.
- `backend/main.py`: `uvicorn backend.main:app` entrypoint.
- `backend/alembic/`: migrations.
- `backend/scripts/generate_token.py`: token helper.
- `backend/requirements.txt`: FastAPI, SQLAlchemy, Alembic, psycopg, pytest, httpx.
- `backend/Dockerfile`: API container.
- `docker-compose.yml`: API + Postgres stack.
- `.env.example`: safe template, never real secrets.
- `backend/README.md`: user setup docs.

## Minimal API Contract

Keep upload endpoint stable:

```text
POST /api/apple-health/sync
Authorization: Bearer <API_TOKEN>
Content-Type: application/json
```

Add read endpoints:

```text
GET /health
GET /api/apple-health/metrics
GET /api/apple-health/workouts
GET /api/apple-health/syncs
```

All `/api/apple-health/*` endpoints require the bearer token.

## Database Schema

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

## Env Vars

Use these names consistently:

```text
DATABASE_URL=postgresql+psycopg://USER:PASSWORD@HOST:PORT/DATABASE
API_TOKEN=<long-random-token>
POSTGRES_DB=healthsync
POSTGRES_USER=healthsync
POSTGRES_PASSWORD=<local-db-password>
POSTGRES_HOST_PORT=15432
API_HOST_PORT=8080
```

Do not commit `.env`.

## User Setup: Docker Or Self-Hosted

Tell the user:

```bash
cp .env.example .env
python3 -m backend.scripts.generate_token
```

Then instruct them to paste the generated token into `.env` as `API_TOKEN`, replace `POSTGRES_PASSWORD`, and run:

```bash
docker compose up --build
```

App settings:

- Simulator backend URL: `http://127.0.0.1:8080`
- Real iPhone same-Wi-Fi backend URL: `http://<mac-lan-ip>:8080`
- Production iPhone backend URL: HTTPS URL only
- Auth token: same value as backend `API_TOKEN`

## User Setup: Supabase Or Neon

Tell the user:

1. Create a Postgres database in Supabase or Neon.
2. Copy a pooled Postgres connection string.
3. Set env vars:

```bash
export DATABASE_URL='postgresql+psycopg://USER:PASSWORD@HOST:PORT/DATABASE'
export API_TOKEN="$(python3 -m backend.scripts.generate_token)"
```

4. Install and migrate:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
alembic upgrade head
```

5. Run or deploy:

```bash
uvicorn backend.main:app --host 0.0.0.0 --port 8080
```

## Verification Commands

Run what exists in the repo. Typical checks:

```bash
python3 -m compileall backend Tests/backend
python3 -m pytest Tests/backend/test_backend_api.py -q
docker compose --env-file .env.example config
env DATABASE_URL=sqlite+pysqlite:////private/tmp/healthsync-alembic-test.sqlite alembic upgrade head
```

If dependencies are missing, create a local `.venv` and install `backend/requirements.txt`. If network access is blocked, request approval rather than silently skipping dependency installation.

## Fetch Examples

Use the user's real token:

```bash
curl -H "Authorization: Bearer $API_TOKEN" \
  "http://127.0.0.1:8080/api/apple-health/metrics?device_id=device-1&type=stepCount"

curl -H "Authorization: Bearer $API_TOKEN" \
  "http://127.0.0.1:8080/api/apple-health/workouts?device_id=device-1"

curl -H "Authorization: Bearer $API_TOKEN" \
  "http://127.0.0.1:8080/api/apple-health/syncs?device_id=device-1"
```

## Troubleshooting

- `401`: missing `Authorization: Bearer <token>` header.
- `403`: token does not match `API_TOKEN`.
- App sync succeeds but no rows appear: confirm the app is pointed at the persistent backend, not `backend_stub`.
- Docker cannot start API: validate `.env`, then run `docker compose --env-file .env config`.
- Real iPhone cannot connect: use HTTPS in production, or verify same-Wi-Fi LAN IP and iOS Local Network permission for local testing.
- Duplicate records: expected on retries; rows should be updated, not multiplied.
