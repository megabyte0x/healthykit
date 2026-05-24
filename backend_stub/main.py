from __future__ import annotations

from typing import Any

from fastapi import FastAPI, Header, HTTPException, Request

app = FastAPI(title="HealthSync backend stub")


@app.post("/api/apple-health/sync")
async def apple_health_sync(
    request: Request,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")

    payload = await request.json()
    metrics = payload.get("metrics") or []
    workouts = payload.get("workouts") or []
    received = len(metrics) + len(workouts)

    print(
        "accepted apple health sync "
        f"device_id={payload.get('device_id', 'unknown')} "
        f"export_id={payload.get('export_id', 'unknown')} "
        f"metrics={len(metrics)} workouts={len(workouts)}"
    )

    return {"ok": True, "received": received, "duplicates": 0}
