from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


JsonMetadata = dict[str, object]


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
    metadata: JsonMetadata = Field(default_factory=dict)


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
    metadata: JsonMetadata = Field(default_factory=dict)


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


class HostedAgentTokenResponse(BaseModel):
    workspace_id: str
    agent_endpoint: str
    agent_token: str


class AgentRange(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    from_at: datetime | None = Field(default=None, alias="from")
    to: datetime | None = None


class PageInfo(BaseModel):
    limit: int
    offset: int
    has_more: bool


class AgentDevice(BaseModel):
    device_id: str
    label: str | None


class AgentCatalog(BaseModel):
    metric_types: list[str]
    activity_types: list[str]
    timezones: list[str]
    devices: list[AgentDevice]


class HealthMetricOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    device_id: str
    type: str
    value: float
    unit: str
    start_at: datetime
    end_at: datetime
    timezone: str
    local_date: str
    source_name: str
    source_bundle_id: str | None
    metadata: JsonMetadata
    export_id: str


class HealthWorkoutOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    device_id: str
    activity_type: str
    start_at: datetime
    end_at: datetime
    timezone: str
    local_date: str
    duration_seconds: float
    total_energy_kcal: float | None
    active_energy_kcal: float | None
    distance_meters: float | None
    source_name: str
    source_bundle_id: str | None
    metadata: JsonMetadata
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
    page: PageInfo


class WorkoutListResponse(BaseModel):
    items: list[HealthWorkoutOut]
    page: PageInfo


class SyncBatchListResponse(BaseModel):
    items: list[SyncBatchOut]
    page: PageInfo


class MetricDailySummary(BaseModel):
    local_date: str
    type: str
    unit: str
    sample_count: int
    total_value: float
    average_value: float
    minimum_value: float
    maximum_value: float


class WorkoutDailySummary(BaseModel):
    local_date: str
    activity_type: str
    workout_count: int
    duration_minutes: float
    distance_km: float | None
    total_energy_kcal: float | None
    active_energy_kcal: float | None


class AgentHealthDataResponse(BaseModel):
    agent_schema_version: int
    workspace_id: str
    range: AgentRange
    page: PageInfo
    catalog: AgentCatalog
    metrics: list[HealthMetricOut]
    workouts: list[HealthWorkoutOut]
    syncs: list[SyncBatchOut]
    metric_daily_summaries: list[MetricDailySummary]
    workout_daily_summaries: list[WorkoutDailySummary]
