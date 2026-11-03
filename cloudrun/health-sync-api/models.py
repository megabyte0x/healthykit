from datetime import datetime
from typing import Literal
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from pydantic import BaseModel, Field, AwareDatetime, ConfigDict, model_validator

class Metric(BaseModel):
    model_config = ConfigDict(extra='forbid',allow_inf_nan=False)
    id: str = Field(min_length=1,max_length=256)
    type: str = Field(min_length=1,max_length=100)
    value: float
    unit: str = Field(min_length=1,max_length=32)
    start_at: AwareDatetime
    end_at: AwareDatetime
    source_name: str = Field(max_length=512)
    source_bundle_id: str | None = Field(default=None,max_length=512)
    metadata: dict = Field(default_factory=dict)

    @model_validator(mode='after')
    def ordered(self):
        if self.end_at < self.start_at: raise ValueError('end before start')
        return self

class Workout(BaseModel):
    model_config = ConfigDict(extra='forbid',allow_inf_nan=False)
    id: str = Field(min_length=1,max_length=256)
    activity_type: str = Field(min_length=1,max_length=100)
    start_at: AwareDatetime
    end_at: AwareDatetime
    duration_seconds: float = Field(ge=0)
    total_energy_kcal: float | None = None
    active_energy_kcal: float | None = None
    distance_meters: float | None = None
    source_name: str = Field(max_length=512)
    source_bundle_id: str | None = Field(default=None,max_length=512)
    metadata: dict = Field(default_factory=dict)

    @model_validator(mode='after')
    def ordered(self):
        if self.end_at < self.start_at: raise ValueError('end before start')
        return self

class DateRange(BaseModel):
    start: AwareDatetime
    end: AwareDatetime
    @model_validator(mode='after')
    def ordered(self):
        if self.end < self.start: raise ValueError('end before start')
        return self

class Deletion(BaseModel):
    id: str = Field(min_length=1,max_length=256)
    kind: Literal['metric','workout']

class Batch(BaseModel):
    model_config = ConfigDict(extra='forbid')
    device_id: str = Field(min_length=1,max_length=128)
    export_id: UUID
    generated_at: AwareDatetime
    timezone: str = Field(max_length=100)
    source: str = Field(max_length=200)
    schema_version: Literal[1, 2]
    date_range: DateRange
    metrics: list[Metric] = Field(default_factory=list,max_length=1000)
    workouts: list[Workout] = Field(default_factory=list,max_length=1000)
    deletions: list[Deletion] = Field(default_factory=list,max_length=1000)

    @model_validator(mode='after')
    def valid(self):
        try: ZoneInfo(self.timezone)
        except (ValueError,ZoneInfoNotFoundError): raise ValueError('Unknown timezone')
        if len(self.metrics)+len(self.workouts)+len(self.deletions)>1000: raise ValueError('Batch too large')
        return self
