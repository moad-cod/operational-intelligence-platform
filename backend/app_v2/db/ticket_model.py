from datetime import datetime, timezone

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app_v2.db.database import Base


class TicketDB(Base):
    __tablename__ = "tickets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    priority: Mapped[str] = mapped_column(
        String(20), default="medium", nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(20), default="open", nullable=False
    )
    category: Mapped[str | None] = mapped_column(String(100), nullable=True)
    department: Mapped[str | None] = mapped_column(String(100), nullable=True)
    location: Mapped[str | None] = mapped_column(String(100), nullable=True)
    device_name: Mapped[str | None] = mapped_column(String(200), nullable=True)

    created_by: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id"), nullable=False
    )
    assigned_to: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("users.id"), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    resolution_notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    sla_deadline: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    escalation_level: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    ai_classification: Mapped[str | None] = mapped_column(
        String(100), nullable=True
    )
    ai_confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    ai_suggestion: Mapped[str | None] = mapped_column(Text, nullable=True)
    ai_suggestion_sources: Mapped[str | None] = mapped_column(
        Text, nullable=True
    )

    creator = relationship("UserDB", foreign_keys=[created_by])
    assignee = relationship("UserDB", foreign_keys=[assigned_to])
