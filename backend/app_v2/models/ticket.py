from datetime import datetime
from pydantic import BaseModel, Field


class TicketCreate(BaseModel):
    title: str = Field(min_length=3, max_length=200)
    description: str = Field(min_length=10)
    priority: str = Field(default="medium", pattern=r"^(low|medium|high|critical)$")
    category: str | None = Field(default=None, max_length=100)
    department: str | None = Field(default=None, max_length=100)
    location: str | None = Field(default=None, max_length=100)
    device_name: str | None = Field(default=None, max_length=200)


class TicketUpdate(BaseModel):
    status: str | None = Field(
        default=None, pattern=r"^(open|assigned|in_progress|resolved|closed)$"
    )
    assigned_to: int | None = None
    priority: str | None = Field(
        default=None, pattern=r"^(low|medium|high|critical)$"
    )
    resolution_notes: str | None = None
    category: str | None = None


class TimelineEventOut(BaseModel):
    id: int
    event_type: str
    description: str
    actor: str
    created_at: datetime

    class Config:
        from_attributes = True


class TicketOut(BaseModel):
    id: int
    title: str
    description: str
    priority: str
    status: str
    category: str | None
    department: str | None = None
    location: str | None = None
    device_name: str | None = None
    created_by: int
    assigned_to: int | None
    created_at: datetime
    updated_at: datetime
    resolved_at: datetime | None
    resolution_notes: str | None
    escalation_level: int
    ai_classification: str | None
    ai_confidence: float | None
    ai_suggestion: str | None
    timeline: list[TimelineEventOut] = []

    class Config:
        from_attributes = True


class TicketListOut(BaseModel):
    id: int
    title: str
    priority: str
    status: str
    category: str | None
    created_at: datetime
    updated_at: datetime
    assigned_to: int | None

    class Config:
        from_attributes = True


class FeedbackCreate(BaseModel):
    was_helpful: bool | None = None
    rating: int | None = Field(default=None, ge=1, le=5)
    comment: str | None = Field(default=None, max_length=1000)


class FeedbackOut(BaseModel):
    id: int
    ticket_id: int
    user_id: int
    was_helpful: bool | None
    rating: int | None
    comment: str | None
    created_at: datetime

    class Config:
        from_attributes = True


class AIAnalysisOut(BaseModel):
    classification: str | None
    confidence: float | None
    suggestion: str | None
    sources: list[str]
