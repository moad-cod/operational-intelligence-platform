import json
import logging
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app_v2.db import ticket_repository as repo
from app_v2.db.ticket_model import TicketDB
from app_v2.models.ticket import (
    FeedbackCreate,
    FeedbackOut,
    TicketCreate,
    TicketListOut,
    TicketOut,
    TicketUpdate,
    TimelineEventOut,
)
from app_v2.services.query_service import QueryService
from app_v2.services.retrieval_service import RetrievalService
from app_v2.services.rerank_service import ReRankService
from app_v2.services.generation_service import GenerationService

logger = logging.getLogger(__name__)


class TicketService:

    def __init__(
        self,
        db: AsyncSession,
        query_svc: QueryService | None = None,
        retrieval_svc: RetrievalService | None = None,
        rerank_svc: ReRankService | None = None,
        generation_svc: GenerationService | None = None,
    ) -> None:
        self.db = db
        self.query_svc = query_svc
        self.retrieval_svc = retrieval_svc
        self.rerank_svc = rerank_svc
        self.generation_svc = generation_svc

    async def create_ticket(
        self, data: TicketCreate, user_id: int
    ) -> TicketOut:
        ticket = await repo.create_ticket(
            title=data.title,
            description=data.description,
            priority=data.priority,
            category=data.category,
            department=data.department,
            location=data.location,
            device_name=data.device_name,
            created_by=user_id,
            db=self.db,
        )

        ai_analysis = None
        if self.query_svc and self.retrieval_svc and self.generation_svc:
            try:
                ai_analysis = await self._run_ai_analysis(ticket)
            except Exception as exc:
                logger.warning("AI analysis failed for ticket %d: %s", ticket.id, exc)

        if ai_analysis:
            update_data = {
                "ai_classification": ai_analysis.get("classification"),
                "ai_confidence": ai_analysis.get("confidence"),
                "ai_suggestion": ai_analysis.get("suggestion"),
                "ai_suggestion_sources": json.dumps(
                    ai_analysis.get("sources", [])
                ),
            }
            ticket = await repo.update_ticket(
                ticket.id,
                {k: v for k, v in update_data.items() if v is not None},
                self.db,
                actor="ai_engine",
            )
            if ai_analysis.get("classification"):
                await repo.add_timeline_event(
                    ticket_id=ticket.id,
                    event_type="classified",
                    description=(
                        f"AI classified as {ai_analysis['classification']} "
                        f"with {ai_analysis['confidence']:.0%} confidence"
                    ),
                    actor="AI Engine",
                    db=self.db,
                )

        return await self._ticket_to_out(ticket)

    async def get_my_tickets(self, user_id: int) -> list[TicketListOut]:
        tickets = await repo.get_tickets_by_user(user_id, self.db)
        return [self._ticket_to_list_out(t) for t in tickets]

    async def get_ticket_detail(
        self, ticket_id: int, user_id: int, user_role: str = "employee"
    ) -> TicketOut:
        ticket = await repo.get_ticket_by_id(ticket_id, self.db)
        if not ticket:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found"
            )
        if user_role == "employee" and ticket.created_by != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized to view this ticket",
            )
        return await self._ticket_to_out(ticket)

    async def update_ticket(
        self, ticket_id: int, data: TicketUpdate, actor: str
    ) -> TicketOut:
        ticket = await repo.update_ticket(
            ticket_id,
            data.model_dump(exclude_none=True),
            self.db,
            actor=actor,
        )
        if data.status == "resolved":
            await repo.add_timeline_event(
                ticket_id=ticket.id,
                event_type="resolved",
                description="Ticket resolved",
                actor=actor,
                db=self.db,
            )
        return await self._ticket_to_out(ticket)

    async def submit_feedback(
        self, ticket_id: int, user_id: int, data: FeedbackCreate
    ) -> FeedbackOut:
        ticket = await repo.get_ticket_by_id(ticket_id, self.db)
        if not ticket:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Ticket not found"
            )
        feedback = await repo.create_feedback(
            ticket_id=ticket_id,
            user_id=user_id,
            was_helpful=data.was_helpful,
            rating=data.rating,
            comment=data.comment,
            db=self.db,
        )
        return FeedbackOut(
            id=feedback.id,
            ticket_id=feedback.ticket_id,
            user_id=feedback.user_id,
            was_helpful=feedback.was_helpful,
            rating=feedback.rating,
            comment=feedback.comment,
            created_at=feedback.created_at,
        )

    async def _run_ai_analysis(self, ticket: TicketDB) -> dict:
        query_data = await self.query_svc.prepare_query(
            f"{ticket.title} {ticket.description}", expand=True
        )
        retrieval_results = await self.retrieval_svc.retrieve(
            dense_vector=query_data["dense_vector"],
            sparse_indices=query_data["sparse_indices"],
            sparse_values=query_data["sparse_values"],
        )
        reranked = await self.rerank_svc.rerank(
            query=query_data["original_query"],
            candidates=retrieval_results,
        )
        result = await self.generation_svc.generate(
            query=query_data["original_query"],
            reranked_chunks=reranked,
        )
        return {
            "classification": ticket.category or "General",
            "confidence": result.get("confidence", 0.0),
            "suggestion": result.get("solution"),
            "sources": result.get("sources", []),
        }

    async def _ticket_to_out(self, ticket: TicketDB) -> TicketOut:
        timeline = await repo.get_timeline(ticket.id, self.db)
        sources_raw = ticket.ai_suggestion_sources
        return TicketOut(
            id=ticket.id,
            title=ticket.title,
            description=ticket.description,
            priority=ticket.priority,
            status=ticket.status,
            category=ticket.category,
            department=ticket.department,
            location=ticket.location,
            device_name=ticket.device_name,
            created_by=ticket.created_by,
            assigned_to=ticket.assigned_to,
            created_at=ticket.created_at,
            updated_at=ticket.updated_at,
            resolved_at=ticket.resolved_at,
            resolution_notes=ticket.resolution_notes,
            escalation_level=ticket.escalation_level,
            ai_classification=ticket.ai_classification,
            ai_confidence=ticket.ai_confidence,
            ai_suggestion=ticket.ai_suggestion,
            timeline=[
                TimelineEventOut(
                    id=e.id,
                    event_type=e.event_type,
                    description=e.description,
                    actor=e.actor,
                    created_at=e.created_at,
                )
                for e in timeline
            ],
        )

    @staticmethod
    def _ticket_to_list_out(t: TicketDB) -> TicketListOut:
        return TicketListOut(
            id=t.id,
            title=t.title,
            priority=t.priority,
            status=t.status,
            category=t.category,
            created_at=t.created_at,
            updated_at=t.updated_at,
            assigned_to=t.assigned_to,
        )
