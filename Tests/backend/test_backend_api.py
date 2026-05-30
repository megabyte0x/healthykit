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
    app = create_app(
        Settings(database_url=database_url, api_token="test-token"),
        session_factory=session_factory,
    )
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
    assert metrics.json()["items"][0]["metadata"] == {"HKWasUserEntered": "false"}

    workouts = client.get("/api/apple-health/workouts?device_id=device-1", headers=headers)
    assert workouts.status_code == 200
    assert workouts.json()["items"][0]["id"] == "healthkit:workout-1"
    assert workouts.json()["items"][0]["metadata"] == {"weather": "clear"}

    syncs = client.get("/api/apple-health/syncs?device_id=device-1", headers=headers)
    assert syncs.status_code == 200
    assert syncs.json()["items"][0]["export_id"] == "11111111-1111-4111-8111-111111111111"


def test_fetch_endpoints_require_token(tmp_path: Path) -> None:
    client = make_client(tmp_path)
    assert client.get("/api/apple-health/metrics").status_code == 401
    assert client.get("/api/apple-health/workouts").status_code == 401
    assert client.get("/api/apple-health/syncs").status_code == 401
