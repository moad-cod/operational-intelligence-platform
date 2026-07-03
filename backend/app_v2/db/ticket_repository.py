from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app_v2.db.ticket_model import TicketDB
from app_v2.db.timeline_model import TicketTimelineDB
from app_v2.db.feedback_model import AIFeedbackDB


async def create_ticket(
    title: str,
    description: str,
    priority: str,
    category: str | None,
    created_by: int,
    db: AsyncSession,
    department: str | None = None,
    location: str | None = None,
    device_name: str | None = None,
) -> TicketDB:
    ticket = TicketDB(
        title=title,
        description=description,
        priority=priority,
        category=category,
        department=department,
        location=location,
        device_name=device_name,
        created_by=created_by,
    )
    db.add(ticket)
    await db.commit()
    await db.refresh(ticket)

    await add_timeline_event(
        ticket_id=ticket.id,
        event_type="created",
        description=f"Ticket created with priority {priority}",
        actor=f"user:{created_by}",
        db=db,
    )
    return ticket


async def get_ticket_by_id(ticket_id: int, db: AsyncSession) -> TicketDB | None:
    result = await db.execute(select(TicketDB).where(TicketDB.id == ticket_id))
    return result.scalar_one_or_none()


async def get_tickets_by_user(
    user_id: int, db: AsyncSession
) -> list[TicketDB]:
    result = await db.execute(
        select(TicketDB)
        .where(TicketDB.created_by == user_id)
        .order_by(TicketDB.created_at.desc())
    )
    return list(result.scalars().all())


async def get_all_tickets(
    db: AsyncSession,
    status_filter: str | None = None,
    priority_filter: str | None = None,
) -> list[TicketDB]:
    query = select(TicketDB).order_by(TicketDB.created_at.desc())
    if status_filter:
        query = query.where(TicketDB.status == status_filter)
    if priority_filter:
        query = query.where(TicketDB.priority == priority_filter)
    result = await db.execute(query)
    return list(result.scalars().all())


async def get_assigned_tickets(
    user_id: int, db: AsyncSession
) -> list[TicketDB]:
    result = await db.execute(
        select(TicketDB)
        .where(TicketDB.assigned_to == user_id)
        .order_by(TicketDB.created_at.desc())
    )
    return list(result.scalars().all())


async def update_ticket(
    ticket_id: int,
    values: dict,
    db: AsyncSession,
    actor: str = "system",
) -> TicketDB:
    ticket = await get_ticket_by_id(ticket_id, db)
    if not ticket:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found"
        )

    changed = []
    for key, val in values.items():
        if val is not None and hasattr(ticket, key):
            old_val = getattr(ticket, key)
            if old_val != val:
                setattr(ticket, key, val)
                changed.append(f"{key}: {old_val} -> {val}")

    if "status" in values and values["status"] == "resolved":
        ticket.resolved_at = datetime.now(timezone.utc)

    ticket.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(ticket)

    if changed:
        await add_timeline_event(
            ticket_id=ticket.id,
            event_type="updated",
            description="; ".join(changed),
            actor=actor,
            db=db,
        )

    return ticket


async def add_timeline_event(
    ticket_id: int,
    event_type: str,
    description: str,
    actor: str,
    db: AsyncSession,
) -> TicketTimelineDB:
    event = TicketTimelineDB(
        ticket_id=ticket_id,
        event_type=event_type,
        description=description,
        actor=actor,
    )
    db.add(event)
    await db.commit()
    await db.refresh(event)
    return event


async def get_timeline(ticket_id: int, db: AsyncSession) -> list[TicketTimelineDB]:
    result = await db.execute(
        select(TicketTimelineDB)
        .where(TicketTimelineDB.ticket_id == ticket_id)
        .order_by(TicketTimelineDB.created_at.asc())
    )
    return list(result.scalars().all())


async def create_feedback(
    ticket_id: int,
    user_id: int,
    was_helpful: bool | None,
    rating: int | None,
    comment: str | None,
    db: AsyncSession,
) -> AIFeedbackDB:
    feedback = AIFeedbackDB(
        ticket_id=ticket_id,
        user_id=user_id,
        was_helpful=was_helpful,
        rating=rating,
        comment=comment,
    )
    db.add(feedback)
    await db.commit()
    await db.refresh(feedback)
    return feedback


async def get_feedback_for_ticket(
    ticket_id: int, db: AsyncSession
) -> list[AIFeedbackDB]:
    result = await db.execute(
        select(AIFeedbackDB).where(AIFeedbackDB.ticket_id == ticket_id)
    )
    return list(result.scalars().all())
