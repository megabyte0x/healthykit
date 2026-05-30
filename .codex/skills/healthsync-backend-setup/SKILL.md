---
name: healthsync-backend-setup
description: Set up, verify, or explain persistent backend storage for the HealthSync iOS app. Use when a user asks an AI agent to make HealthSync data persistent, configure Docker/Postgres, configure Supabase or Neon, run migrations, generate backend tokens, save Apple Health sync data, expose fetch APIs, or troubleshoot the HealthSync backend setup.
---

# HealthSync Backend Setup

## Workflow

Use this skill to take a HealthSync repo from a local request-shape stub to working persistent storage for users.

1. Inspect the repo before editing:
   - Confirm the app posts to `POST /api/apple-health/sync`.
   - Check whether `backend/`, `docker-compose.yml`, `.env.example`, `alembic.ini`, and `backend/README.md` already exist.
   - Preserve unrelated worktree changes.
2. Choose the setup path:
   - Docker/local or VPS: use Compose with API + Postgres.
   - Managed Postgres: use Supabase/Neon via `DATABASE_URL`.
   - If both are needed, keep one backend codebase and make both paths share migrations and env vars.
3. Ensure the backend contract:
   - Validate `Authorization: Bearer <API_TOKEN>`.
   - Persist devices, sync batches, metrics, and workouts.
   - Deduplicate by `device_id + id` for metric/workout records.
   - Expose fetch endpoints for metrics, workouts, and sync batches.
4. Verify setup end to end:
   - Run backend tests.
   - Run migration smoke checks.
   - Validate Docker Compose config.
   - Give the user exact app settings: backend URL and token.

For the concrete schema, env vars, commands, and verification checklist, read `references/healthsync-backend.md`.

## Implementation Rules

- Do not change the iOS upload payload unless the user explicitly asks.
- Keep the existing endpoint stable: `/api/apple-health/sync`.
- Store the auth token only in the app Keychain; backend users set the same value as `API_TOKEN`.
- Require HTTPS for production real-device sync; local LAN HTTP is only for trusted testing.
- Prefer Postgres for persistent storage. Use SQLite only for fast local tests.
- Add or keep tests for auth failures, sync persistence, duplicate syncs, metric fetches, workout fetches, and sync listing.
- Do not stage unrelated files, especially local `.env`, `.venv`, derived data, or user scratch files.

## Common User Requests

- "Make HealthSync save data into a real database."
- "Set up Supabase/Neon for the HealthSync backend."
- "Give users an easy Docker backend for HealthSync."
- "Show how users fetch synced health metrics."
- "Troubleshoot why HealthSync uploaded but nothing persisted."
