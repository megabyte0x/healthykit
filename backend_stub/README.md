# HealthSync Backend Stub

This is a local-only FastAPI stub for testing the iOS app's sync request shape. It validates that an `Authorization: Bearer ...` header exists, prints summary counts only, and returns an accepted response.

It does not persist data. Use `backend/` for the real Postgres-backed service with Docker, migrations, and fetch APIs.

Run it with:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend_stub/requirements.txt
uvicorn backend_stub.main:app --host 0.0.0.0 --port 8080
```

Use `http://127.0.0.1:8080` from the simulator, or an HTTPS-reachable URL from a real iPhone.
