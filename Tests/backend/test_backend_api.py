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
    assert first.json() == {"ok": True, "received": 2, "duplicates": 0, "deleted": 0}

    second = client.post("/api/apple-health/sync", headers=headers, json=sample_payload())
    assert second.status_code == 200
    assert second.json() == {"ok": True, "received": 2, "duplicates": 2, "deleted": 0}


def test_sync_upserts_newest_values_for_existing_record_ids(tmp_path: Path) -> None:
    client = make_client(tmp_path)
    headers = {"Authorization": "Bearer test-token"}
    assert client.post("/api/apple-health/sync", headers=headers, json=sample_payload()).status_code == 200

    updated = sample_payload("22222222-2222-4222-8222-222222222222")
    updated["metrics"][0]["value"] = 9876
    updated["metrics"][0]["metadata"] = {"corrected": True}
    response = client.post("/api/apple-health/sync", headers=headers, json=updated)

    assert response.status_code == 200
    assert response.json() == {"ok": True, "received": 2, "duplicates": 2, "deleted": 0}
    metrics = client.get("/api/apple-health/metrics?device_id=device-1", headers=headers).json()["items"]
    assert len(metrics) == 1
    assert metrics[0]["value"] == 9876
    assert metrics[0]["metadata"] == {"corrected": True}


def test_empty_sync_is_accepted_without_persisting_empty_batch(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)
    provisioned = client.post("/api/hosted/workspaces", json={"label": "Personal Health"}).json()
    payload = sample_payload()
    payload["metrics"] = []
    payload["workouts"] = []

    response = client.post(
        "/api/apple-health/sync",
        headers={"Authorization": f"Bearer {provisioned['ingest_token']}", "X-App-Version": "1.0"},
        json=payload,
    )

    assert response.status_code == 200
    assert response.json() == {"ok": True, "received": 0, "duplicates": 0, "deleted": 0}
    with client.app.state.session_factory() as db:
        from backend.models import SyncBatchRecord

        assert db.query(SyncBatchRecord).count() == 0


def test_sync_deletions_are_device_scoped_and_idempotent(tmp_path: Path) -> None:
    client = make_client(tmp_path)
    headers = {"Authorization": "Bearer test-token"}
    assert client.post("/api/apple-health/sync", headers=headers, json=sample_payload()).status_code == 200

    wrong_device_deletion = sample_payload("22222222-2222-4222-8222-222222222222")
    wrong_device_deletion["device_id"] = "device-2"
    wrong_device_deletion["metrics"] = []
    wrong_device_deletion["workouts"] = []
    wrong_device_deletion["deletions"] = [
        {"id": "healthkit:metric-1", "kind": "metric"},
        {"id": "healthkit:workout-1", "kind": "workout"},
    ]
    wrong_device = client.post("/api/apple-health/sync", headers=headers, json=wrong_device_deletion)
    assert wrong_device.status_code == 200
    assert wrong_device.json()["deleted"] == 0

    deletion = deepcopy(wrong_device_deletion)
    deletion["device_id"] = "device-1"
    deletion["export_id"] = "33333333-3333-4333-8333-333333333333"
    first = client.post("/api/apple-health/sync", headers=headers, json=deletion)
    second = client.post("/api/apple-health/sync", headers=headers, json=deletion)

    assert first.status_code == 200
    assert first.json() == {"ok": True, "received": 0, "duplicates": 0, "deleted": 2}
    assert second.status_code == 200
    assert second.json() == {"ok": True, "received": 0, "duplicates": 0, "deleted": 0}
    assert client.get("/api/apple-health/metrics?device_id=device-1", headers=headers).json()["items"] == []
    assert client.get("/api/apple-health/workouts?device_id=device-1", headers=headers).json()["items"] == []


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


def test_hosted_deletions_cannot_cross_workspace_boundaries(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)
    first = client.post("/api/hosted/workspaces", json={"label": "First"}).json()
    second = client.post("/api/hosted/workspaces", json={"label": "Second"}).json()
    first_ingest = {"Authorization": f"Bearer {first['ingest_token']}"}
    second_ingest = {"Authorization": f"Bearer {second['ingest_token']}"}
    first_agent = {"Authorization": f"Bearer {first['agent_token']}"}
    second_agent = {"Authorization": f"Bearer {second['agent_token']}"}

    assert client.post("/api/apple-health/sync", headers=first_ingest, json=sample_payload()).status_code == 200
    assert client.post("/api/apple-health/sync", headers=second_ingest, json=sample_payload()).status_code == 200

    deletion = sample_payload("22222222-2222-4222-8222-222222222222")
    deletion["metrics"] = []
    deletion["workouts"] = []
    deletion["deletions"] = [
        {"id": "healthkit:metric-1", "kind": "metric"},
        {"id": "healthkit:workout-1", "kind": "workout"},
    ]
    response = client.post("/api/apple-health/sync", headers=first_ingest, json=deletion)

    assert response.status_code == 200
    assert response.json()["deleted"] == 2
    assert client.get("/api/agent/health-data", headers=first_agent).json()["metrics"] == []
    assert client.get("/api/agent/health-data", headers=first_agent).json()["workouts"] == []
    assert len(client.get("/api/agent/health-data", headers=second_agent).json()["metrics"]) == 1
    assert len(client.get("/api/agent/health-data", headers=second_agent).json()["workouts"]) == 1


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


def test_hosted_agent_token_can_be_rotated_with_ingest_token(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)
    provisioned = client.post("/api/hosted/workspaces", json={"label": "Personal Health"}).json()
    ingest_headers = {"Authorization": f"Bearer {provisioned['ingest_token']}"}
    old_agent_headers = {"Authorization": f"Bearer {provisioned['agent_token']}"}
    client.post("/api/apple-health/sync", headers=ingest_headers, json=sample_payload())

    response = client.post("/api/hosted/agent-token", headers=ingest_headers)

    assert response.status_code == 200
    rotated = response.json()
    assert rotated["workspace_id"] == provisioned["workspace_id"]
    assert rotated["agent_endpoint"] == "https://healthsync.example.test/api/agent/health-data"
    assert rotated["agent_token"].startswith("hs_agent_")
    assert rotated["agent_token"] != provisioned["agent_token"]

    old_read = client.get("/api/agent/health-data", headers=old_agent_headers)
    assert old_read.status_code == 403

    new_read = client.get(
        "/api/agent/health-data",
        headers={"Authorization": f"Bearer {rotated['agent_token']}"},
    )
    assert new_read.status_code == 200
    assert new_read.json()["workspace_id"] == provisioned["workspace_id"]
    assert len(new_read.json()["metrics"]) == 1


def test_hosted_agent_token_rotation_rejects_agent_token(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)
    provisioned = client.post("/api/hosted/workspaces", json={"label": "Personal Health"}).json()

    response = client.post(
        "/api/hosted/agent-token",
        headers={"Authorization": f"Bearer {provisioned['agent_token']}"},
    )

    assert response.status_code == 403


def test_hosted_workspace_reset_deletes_current_workspace_and_returns_new_host(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)
    provisioned = client.post("/api/hosted/workspaces", json={"label": "Personal Health"}).json()
    other = client.post("/api/hosted/workspaces", json={"label": "Other Device"}).json()
    ingest_headers = {"Authorization": f"Bearer {provisioned['ingest_token']}"}
    old_agent_headers = {"Authorization": f"Bearer {provisioned['agent_token']}"}

    client.post("/api/apple-health/sync", headers=ingest_headers, json=sample_payload())
    client.post(
        "/api/apple-health/sync",
        headers={"Authorization": f"Bearer {other['ingest_token']}"},
        json=sample_payload("22222222-2222-4222-8222-222222222222"),
    )

    response = client.post(
        "/api/hosted/workspaces/reset",
        headers=ingest_headers,
        json={"label": "Personal Health"},
    )

    assert response.status_code == 200
    reset = response.json()
    assert reset["workspace_id"].startswith("wk_")
    assert reset["workspace_id"] != provisioned["workspace_id"]
    assert reset["backend_url"] == "https://healthsync.example.test"
    assert reset["ingest_token"].startswith("hs_ingest_")
    assert reset["agent_token"].startswith("hs_agent_")
    assert reset["agent_endpoint"] == "https://healthsync.example.test/api/agent/health-data"

    assert client.get("/api/agent/health-data", headers=old_agent_headers).status_code == 403
    assert client.post("/api/apple-health/sync", headers=ingest_headers, json=sample_payload()).status_code == 403

    new_read = client.get(
        "/api/agent/health-data",
        headers={"Authorization": f"Bearer {reset['agent_token']}"},
    )
    assert new_read.status_code == 200
    assert new_read.json()["workspace_id"] == reset["workspace_id"]
    assert new_read.json()["metrics"] == []
    assert new_read.json()["workouts"] == []
    assert new_read.json()["syncs"] == []

    other_read = client.get(
        "/api/agent/health-data",
        headers={"Authorization": f"Bearer {other['agent_token']}"},
    )
    assert other_read.status_code == 200
    assert other_read.json()["workspace_id"] == other["workspace_id"]
    assert [item["export_id"] for item in other_read.json()["syncs"]] == ["22222222-2222-4222-8222-222222222222"]


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


def test_agent_daily_summary_uses_all_matching_samples_not_only_current_page(tmp_path: Path) -> None:
    client = make_client(tmp_path, hosted=True)
    provisioned = client.post("/api/hosted/workspaces", json={"label": "Personal Health"}).json()
    ingest_headers = {"Authorization": f"Bearer {provisioned['ingest_token']}"}

    payload = sample_payload()
    payload["workouts"] = [
        {
            **payload["workouts"][0],
            "id": f"healthkit:workout-{index}",
            "start_at": f"2026-05-31T0{index}:10:00.000Z",
            "end_at": f"2026-05-31T0{index}:40:00.000Z",
        }
        for index in range(1, 4)
    ]
    payload["metrics"] = [
        {
            **payload["metrics"][0],
            "id": f"healthkit:metric-{index}",
            "value": value,
            "start_at": f"2026-05-31T0{index}:00:00.000Z",
            "end_at": f"2026-05-31T0{index}:05:00.000Z",
        }
        for index, value in enumerate((10, 20, 30), start=1)
    ]
    client.post("/api/apple-health/sync", headers=ingest_headers, json=payload)

    response = client.get(
        "/api/agent/health-data?type=stepCount&limit=2",
        headers={"Authorization": f"Bearer {provisioned['agent_token']}"},
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body["metrics"]) == 2
    assert body["page"]["has_more"] is True
    assert body["metric_daily_summaries"] == [
        {
            "local_date": "2026-05-31",
            "type": "stepCount",
            "unit": "count",
            "sample_count": 3,
            "total_value": 60.0,
            "average_value": 20.0,
            "minimum_value": 10.0,
            "maximum_value": 30.0,
        }
    ]
    assert body["workout_daily_summaries"] == [
        {
            "local_date": "2026-05-31",
            "activity_type": "running",
            "workout_count": 3,
            "duration_minutes": 90.0,
            "distance_km": 15.0,
            "total_energy_kcal": 750.0,
            "active_energy_kcal": 690.0,
        }
    ]
