import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app_v2.core.dependencies import (
    RoleChecker,
    get_current_user,
    get_db,
    get_generation_service,
    get_query_service,
    get_rerank_service,
    get_retrieval_service,
)
from app_v2.db.user_model import UserDB
from app_v2.models.ticket import (
    FeedbackCreate,
    FeedbackOut,
    TicketCreate,
    TicketListOut,
    TicketOut,
    TicketUpdate,
)
from app_v2.services.generation_service import GenerationService
from app_v2.services.query_service import QueryService
from app_v2.services.rerank_service import ReRankService
from app_v2.services.retrieval_service import RetrievalService
from app_v2.services.ticket_service import TicketService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/tickets", tags=["Tickets"])

admin_only = RoleChecker(["admin"])


@router.post("/", response_model=TicketOut, status_code=201)
async def create_ticket(
    data: TicketCreate,
    current_user: UserDB = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    query_svc: QueryService = Depends(get_query_service),
    retrieval_svc: RetrievalService = Depends(get_retrieval_service),
    rerank_svc: ReRankService = Depends(get_rerank_service),
    generation_svc: GenerationService = Depends(get_generation_service),
):
    svc = TicketService(db, query_svc, retrieval_svc, rerank_svc, generation_svc)
    return await svc.create_ticket(data, current_user.id)


@router.get("/my", response_model=list[TicketListOut])
async def get_my_tickets(
    current_user: UserDB = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    svc = TicketService(db)
    return await svc.get_my_tickets(current_user.id)


@router.get("/all", response_model=list[TicketListOut])
async def get_all_tickets(
    current_user: UserDB = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    from app_v2.db import ticket_repository as repo
    tickets = await repo.get_all_tickets(db)
    return [TicketService._ticket_to_list_out(t) for t in tickets]


@router.get("/queue", response_model=list[TicketListOut])
async def get_technician_queue(
    current_user: UserDB = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    from app_v2.db import ticket_repository as repo
    tickets = await repo.get_all_tickets(
        db, status_filter="open"
    )
    return [TicketService._ticket_to_list_out(t) for t in tickets]


@router.get("/assigned", response_model=list[TicketListOut])
async def get_assigned_tickets(
    current_user: UserDB = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    from app_v2.db import ticket_repository as repo
    tickets = await repo.get_assigned_tickets(current_user.id, db)
    return [TicketService._ticket_to_list_out(t) for t in tickets]


@router.get("/{ticket_id}", response_model=TicketOut)
async def get_ticket(
    ticket_id: int,
    current_user: UserDB = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    svc = TicketService(db)
    return await svc.get_ticket_detail(ticket_id, current_user.id, current_user.role)


@router.patch("/{ticket_id}", response_model=TicketOut)
async def update_ticket(
    ticket_id: int,
    data: TicketUpdate,
    current_user: UserDB = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    svc = TicketService(db)
    actor = f"user:{current_user.id}({current_user.username})"
    return await svc.update_ticket(ticket_id, data, actor)


@router.post("/{ticket_id}/feedback", response_model=FeedbackOut)
async def submit_feedback(
    ticket_id: int,
    data: FeedbackCreate,
    current_user: UserDB = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    svc = TicketService(db)
    ticket = await svc.get_ticket_detail(ticket_id, current_user.id, current_user.role)
    if current_user.role == "employee" and ticket.created_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized"
        )
    return await svc.submit_feedback(ticket_id, current_user.id, data)


@router.get("/{ticket_id}/feedback", response_model=list[FeedbackOut])
async def get_feedback(
    ticket_id: int,
    current_user: UserDB = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app_v2.db import ticket_repository as repo
    svc = TicketService(db)
    ticket = await svc.get_ticket_detail(ticket_id, current_user.id, current_user.role)
    if current_user.role == "employee" and ticket.created_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized"
        )
    feedbacks = await repo.get_feedback_for_ticket(ticket_id, db)
    return [
        FeedbackOut(
            id=f.id,
            ticket_id=f.ticket_id,
            user_id=f.user_id,
            was_helpful=f.was_helpful,
            rating=f.rating,
            comment=f.comment,
            created_at=f.created_at,
        )
        for f in feedbacks
    ]


@router.post("/{ticket_id}/assign", response_model=TicketOut)
async def assign_ticket(
    ticket_id: int,
    current_user: UserDB = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    svc = TicketService(db)
    actor = f"user:{current_user.id}({current_user.username})"
    return await svc.update_ticket(
        ticket_id,
        TicketUpdate(assigned_to=current_user.id, status="assigned"),
        actor,
    )


@router.post("/{ticket_id}/resolve", response_model=TicketOut)
async def resolve_ticket(
    ticket_id: int,
    data: TicketUpdate,
    current_user: UserDB = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    svc = TicketService(db)
    actor = f"user:{current_user.id}({current_user.username})"
    return await svc.update_ticket(
        ticket_id,
        TicketUpdate(status="resolved", resolution_notes=data.resolution_notes),
        actor,
    )
