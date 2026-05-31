from __future__ import annotations

from copy import deepcopy
from pathlib import Path

from fastapi.testclient import TestClient

from backend.app import create_app
from backend.config import Settings
from backend.database import create_engine_for_url, create_session_factory
from backend.models import Base


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


def test_hosted_token_capabilities_are_separated(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)
    provisioned = client.post("/api/hosted/workspaces", json={"label": "Personal Health"}).json()
    ingest_headers = {"Authorization": f"Bearer {provisioned['ingest_token']}"}
    agent_headers = {"Authorization": f"Bearer {provisioned['agent_token']}"}

    upload = client.post("/api/apple-health/sync", headers=ingest_headers, json=sample_payload())
    assert upload.status_code == 200

    ingest_read = client.get("/api/agent/metrics", headers=ingest_headers)
    assert ingest_read.status_code == 403

    agent_upload = client.post(
        "/api/apple-health/sync",
        headers=agent_headers,
        json=sample_payload("22222222-2222-4222-8222-222222222222"),
    )
    assert agent_upload.status_code == 403

    agent_read = client.get("/api/agent/metrics", headers=agent_headers)
    assert agent_read.status_code == 200


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


def test_agent_health_data_filters_metrics_by_type(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)
    provisioned = client.post("/api/hosted/workspaces", json={"label": "Personal Health"}).json()
    headers = {"Authorization": f"Bearer {provisioned['ingest_token']}"}

    step_payload = sample_payload()
    heart_rate_payload = deepcopy(sample_payload("22222222-2222-4222-8222-222222222222"))
    heart_rate_payload["device_id"] = "device-2"
    heart_rate_payload["metrics"][0]["id"] = "healthkit:metric-2"
    heart_rate_payload["metrics"][0]["type"] = "heartRate"

    client.post("/api/apple-health/sync", headers=headers, json=step_payload)
    client.post("/api/apple-health/sync", headers=headers, json=heart_rate_payload)

    response = client.get(
        "/api/agent/health-data?type=heartRate",
        headers={"Authorization": f"Bearer {provisioned['agent_token']}"},
    )

    assert response.status_code == 200
    assert [item["type"] for item in response.json()["metrics"]] == ["heartRate"]


def test_agent_health_data_filters_syncs_by_requested_range(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)
    provisioned = client.post("/api/hosted/workspaces", json={"label": "Personal Health"}).json()
    headers = {"Authorization": f"Bearer {provisioned['ingest_token']}"}

    in_range_payload = sample_payload()
    out_of_range_payload = deepcopy(sample_payload("22222222-2222-4222-8222-222222222222"))
    out_of_range_payload["generated_at"] = "2026-04-15T10:00:00.000Z"
    out_of_range_payload["date_range"] = {
        "start": "2026-04-14T10:00:00.000Z",
        "end": "2026-04-15T10:00:00.000Z",
    }

    client.post("/api/apple-health/sync", headers=headers, json=in_range_payload)
    client.post("/api/apple-health/sync", headers=headers, json=out_of_range_payload)

    response = client.get(
        "/api/agent/health-data?from=2026-05-01T00:00:00.000Z&to=2026-05-31T23:59:59.000Z",
        headers={"Authorization": f"Bearer {provisioned['agent_token']}"},
    )

    assert response.status_code == 200
    assert [item["export_id"] for item in response.json()["syncs"]] == ["11111111-1111-4111-8111-111111111111"]


def test_agent_health_data_returns_digest_schema_for_agents(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)
    provisioned = client.post("/api/hosted/workspaces", json={"label": "Personal Health"}).json()
    headers = {"Authorization": f"Bearer {provisioned['ingest_token']}"}

    payload = sample_payload()
    payload["metrics"][0]["metadata"] = {
        "HKWasUserEntered": False,
        "sample_count": 1,
    }
    client.post("/api/apple-health/sync", headers=headers, json=payload)

    response = client.get(
        "/api/agent/health-data",
        headers={"Authorization": f"Bearer {provisioned['agent_token']}"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["agent_schema_version"] == 2
    assert body["page"] == {"limit": 100, "offset": 0, "has_more": False}
    assert body["catalog"] == {
        "metric_types": ["stepCount"],
        "activity_types": ["running"],
        "timezones": ["Asia/Kolkata"],
        "devices": [{"device_id": "device-1", "label": None}],
    }
    assert body["metrics"][0]["local_date"] == "2026-05-31"
    assert body["metrics"][0]["timezone"] == "Asia/Kolkata"
    assert body["metrics"][0]["metadata"] == {
        "HKWasUserEntered": False,
        "sample_count": 1,
    }
    assert body["metric_daily_summaries"] == [
        {
            "local_date": "2026-05-31",
            "type": "stepCount",
            "unit": "count",
            "sample_count": 1,
            "total_value": 1200.0,
            "average_value": 1200.0,
            "minimum_value": 1200.0,
            "maximum_value": 1200.0,
        }
    ]
    assert body["workout_daily_summaries"] == [
        {
            "local_date": "2026-05-31",
            "activity_type": "running",
            "workout_count": 1,
            "duration_minutes": 30.0,
            "distance_km": 5.0,
            "total_energy_kcal": 250.0,
            "active_energy_kcal": 230.0,
        }
    ]


def test_agent_health_data_reports_has_more_when_result_is_limited(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)
    provisioned = client.post("/api/hosted/workspaces", json={"label": "Personal Health"}).json()
    headers = {"Authorization": f"Bearer {provisioned['ingest_token']}"}

    first_payload = sample_payload()
    second_payload = deepcopy(sample_payload("22222222-2222-4222-8222-222222222222"))
    second_payload["device_id"] = "device-2"
    second_payload["metrics"][0]["id"] = "healthkit:metric-2"

    client.post("/api/apple-health/sync", headers=headers, json=first_payload)
    client.post("/api/apple-health/sync", headers=headers, json=second_payload)

    response = client.get(
        "/api/agent/health-data?limit=1",
        headers={"Authorization": f"Bearer {provisioned['agent_token']}"},
    )

    assert response.status_code == 200
    assert response.json()["page"] == {"limit": 1, "offset": 0, "has_more": True}
