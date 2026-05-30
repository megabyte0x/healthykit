---
name: healthsync-backend-setup
description: Set up, verify, or troubleshoot database-backed HealthSync storage for self-hosted and hosted deployments. Use when an AI agent must configure local Docker/Postgres, VPS or self-hosted Postgres, managed Postgres such as Supabase or Neon, hosted HealthSync workspace provisioning, ingest tokens, read-only agent endpoints and tokens, migrations, backend environment variables, or Apple Health sync persistence for HealthSync.
---

# HealthSync Backend Setup

## Start Here

Use this skill to take a HealthSync repo from a request-shape stub or partial backend to working persistent Apple Health storage. Preserve unrelated worktree changes.

1. Inspect the repo before editing:
   - Confirm the app posts to `POST /api/apple-health/sync`.
   - Check whether `backend/`, `docker-compose.yml`, `.env.example`, `alembic.ini`, and `backend/README.md` already exist.
   - Check whether migrations and tests already cover hosted workspaces and read-only agent endpoints.
2. Classify the requested deployment path:
   - Self-hosted full stack: Docker Compose or VPS runs the API and Postgres. The app and self-hosted read APIs use `API_TOKEN`.
   - Managed database with self-hosted API: Supabase, Neon, or another hosted Postgres provides `DATABASE_URL`; the user still runs/deploys the FastAPI backend and uses `API_TOKEN`.
   - Hosted HealthSync service: one deployed API provisions workspaces; the iOS app receives an ingest token, and AI agents receive only a read-only agent endpoint and token.
   - If the user says "hosted DB" but does not ask for per-user workspaces or agent tokens, default to managed database with self-hosted API.
3. Keep one backend codebase when multiple paths are needed. Self-hosted and hosted modes must share schema, migrations, payload parsing, and repository code.
4. Ensure the backend contract:
   - Validate `Authorization: Bearer <API_TOKEN>`.
   - Validate hosted ingest and agent tokens by hash.
   - Never expose database credentials to the iOS app or AI agents.
   - Persist devices, sync batches, metrics, and workouts.
   - Deduplicate by `workspace_id + device_id + id` for metric/workout records.
   - Expose self-hosted fetch endpoints and private read-only hosted agent endpoints for metrics, workouts, sync batches, and aggregate health data.
5. Verify setup end to end:
   - Run backend tests.
   - Run migration smoke checks.
   - Validate Docker Compose config.
   - Give the user exact app settings: backend URL and which token field to use.

For the concrete schema, env vars, commands, and verification checklist, read `references/healthsync-backend.md`.

## Setup Rules

- For local Docker or self-hosted servers, use Postgres behind the FastAPI backend. The iOS app stores the backend URL and `API_TOKEN` in Settings/Keychain.
- For managed Postgres without hosted provisioning, set `DATABASE_URL` where the FastAPI backend runs. Do not configure Supabase credentials in the iOS app.
- For hosted HealthSync mode, require `TOKEN_HASH_SECRET`, `HOSTED_PUBLIC_BASE_URL`, and `HOSTED_PROVISIONING_ENABLED=true`; provision a workspace before giving app or agent settings to a user.
- In hosted mode, give the iOS app only `backend_url` and `ingest_token`; give AI agents only `agent_endpoint` and `agent_token`.
- Keep `API_TOKEN` as the self-hosted/admin token. Do not let hosted agent reads accept `API_TOKEN` or ingest tokens.
- Require HTTPS for production real-device sync. Use LAN HTTP only for trusted local testing.

## Implementation Rules

- Do not change the iOS upload payload unless the user explicitly asks.
- Keep the existing endpoint stable: `/api/apple-health/sync`.
- Store the auth token only in the app Keychain; backend users set the same value as `API_TOKEN`.
- Prefer Postgres for persistent storage. Use SQLite only for fast local tests.
- Add or keep tests for auth failures, sync persistence, duplicate syncs, metric fetches, workout fetches, sync listing, hosted provisioning, and agent token isolation.
- Do not stage unrelated files, especially local `.env`, `.venv`, derived data, or user scratch files.

## Verification Contract

Run the checks that exist in the repo after setup or edits:

- backend import/compile checks
- backend API tests
- migration upgrade smoke checks
- Docker Compose config validation for self-hosted setups

If dependencies or Docker are unavailable, report the exact skipped command and reason. If installation requires network access, request approval before installing.

## User-Facing Output

End with the chosen deployment path, changed files, commands run, and the settings the user must enter. Do not print existing secrets. For generated tokens, either give the exact token only when it was generated for the user in this turn, or identify the variable that must hold it.

## Common User Requests

- "Make HealthSync save data into a real database."
- "Set up self-hosted Postgres for HealthSync."
- "Set up Supabase or Neon for the HealthSync backend."
- "Set up hosted HealthSync workspaces for agents."
- "Give users an easy Docker backend for HealthSync."
- "Give my AI agent a private read-only endpoint for synced health data."
- "Show how users fetch synced health metrics."
- "Troubleshoot why HealthSync uploaded but nothing persisted."
