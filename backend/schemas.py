from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class SyncDateRange(BaseModel):
    start: datetime
    end: datetime


class HealthMetricIn(BaseModel):
    id: str
    type: str
    value: float
    unit: str
    start_at: datetime
    end_at: datetime
    source_name: str
    source_bundle_id: str | None = None
    metadata: dict[str, str] = Field(default_factory=dict)


class HealthWorkoutIn(BaseModel):
    id: str
    activity_type: str
    start_at: datetime
    end_at: datetime
    duration_seconds: float
    total_energy_kcal: float | None = None
    active_energy_kcal: float | None = None
    distance_meters: float | None = None
    source_name: str
    source_bundle_id: str | None = None
    metadata: dict[str, str] = Field(default_factory=dict)


class SyncPayloadIn(BaseModel):
    device_id: str
    export_id: UUID
    generated_at: datetime
    timezone: str
    source: str
    schema_version: int
    date_range: SyncDateRange
    metrics: list[HealthMetricIn] = Field(default_factory=list)
    workouts: list[HealthWorkoutIn] = Field(default_factory=list)


class UploadResult(BaseModel):
    ok: bool
    received: int
    duplicates: int


class HostedWorkspaceCreate(BaseModel):
    label: str | None = None


class HostedWorkspaceResponse(BaseModel):
    workspace_id: str
    backend_url: str
    ingest_token: str
    agent_endpoint: str
    agent_token: str


class HealthMetricOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    device_id: str
    type: str
    value: float
    unit: str
    start_at: datetime
    end_at: datetime
    source_name: str
    source_bundle_id: str | None
    metadata: dict[str, str]
    export_id: str


class HealthWorkoutOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    device_id: str
    activity_type: str
    start_at: datetime
    end_at: datetime
    duration_seconds: float
    total_energy_kcal: float | None
    active_energy_kcal: float | None
    distance_meters: float | None
    source_name: str
    source_bundle_id: str | None
    metadata: dict[str, str]
    export_id: str


class SyncBatchOut(BaseModel):
    export_id: str
    device_id: str
    generated_at: datetime
    received_at: datetime
    schema_version: int
    timezone: str
    source: str
    date_range_start: datetime
    date_range_end: datetime
    metrics_count: int
    workouts_count: int


class MetricListResponse(BaseModel):
    items: list[HealthMetricOut]


class WorkoutListResponse(BaseModel):
    items: list[HealthWorkoutOut]


class SyncBatchListResponse(BaseModel):
    items: list[SyncBatchOut]
