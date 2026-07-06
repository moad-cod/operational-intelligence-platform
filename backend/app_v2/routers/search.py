import logging
import time

from fastapi import APIRouter, Depends

from app_v2.core.dependencies import (
    get_current_user,
    get_generation_service,
    get_query_service,
    get_rerank_service,
    get_retrieval_service,
    get_solution_fetch_service,
)
from app_v2.models.search import (
    ChunkResult,
    RerankResponse,
    RetrievalResponse,
    SearchRequest,
    SearchResponse,
)
from app_v2.models.user import User
from app_v2.services.generation_service import GenerationService
from app_v2.services.query_service import QueryService
from app_v2.services.rerank_service import ReRankService
from app_v2.services.retrieval_service import RetrievalService
from app_v2.services.solution_fetch_service import SolutionFetchService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/search", tags=["Search"])


def _build_chunk_result(d: dict) -> ChunkResult:
    return ChunkResult(
        rag_id=d.get("rag_id", ""),
        document_id=d.get("document_id", ""),
        chunk_text=d.get("chunk_text", ""),
        retrieval_score=d.get("retrieval_score", 0.0),
        llm_score=d.get("llm_score"),
        priority_encoded=d.get("priority_encoded", 0),
        metadata=d.get("metadata", {}),
    )


@router.post("/", response_model=SearchResponse)
async def full_search(
    request: SearchRequest,
    current_user: User = Depends(get_current_user),
    query_svc: QueryService = Depends(get_query_service),
    retrieval_svc: RetrievalService = Depends(get_retrieval_service),
    fetch_svc: SolutionFetchService = Depends(get_solution_fetch_service),
    rerank_svc: ReRankService = Depends(get_rerank_service),
    generation_svc: GenerationService = Depends(get_generation_service),
):
    start = time.time()

    query_data = await query_svc.prepare_query(
        query_text=request.query,
        expand=request.expand_query,
    )

    retrieval_results = await retrieval_svc.retrieve(
        dense_vector=query_data["dense_vector"],
        sparse_indices=query_data["sparse_indices"],
        sparse_values=query_data["sparse_values"],
        metadata_filter=(
            request.filters.model_dump(exclude_none=True)
            if request.filters else None
        ),
    )

    fetched = await fetch_svc.fetch_solutions(retrieval_results)

    reranked = await rerank_svc.rerank(
        query=query_data["original_query"],
        candidates=fetched,
        top_k=request.top_k,
    )

    final = await generation_svc.generate(
        query=query_data["original_query"],
        reranked_chunks=reranked,
    )

    latency_ms = (time.time() - start) * 1000

    return SearchResponse(
        query=query_data["original_query"],
        expanded_query=query_data["expanded_query"],
        solution=final["solution"],
        confidence=final["confidence"],
        sources=final["sources"],
        top_chunks=[_build_chunk_result(c) for c in reranked],
        tokens_used=final["tokens_used"],
        latency_ms=round(latency_ms, 2),
    )


@router.post("/retrieve", response_model=RetrievalResponse)
async def retrieve_only(
    request: SearchRequest,
    current_user: User = Depends(get_current_user),
    query_svc: QueryService = Depends(get_query_service),
    retrieval_svc: RetrievalService = Depends(get_retrieval_service),
):
    start = time.time()

    query_data = await query_svc.prepare_query(
        query_text=request.query,
        expand=request.expand_query,
    )

    results = await retrieval_svc.retrieve(
        dense_vector=query_data["dense_vector"],
        sparse_indices=query_data["sparse_indices"],
        sparse_values=query_data["sparse_values"],
        metadata_filter=(
            request.filters.model_dump(exclude_none=True)
            if request.filters else None
        ),
    )

    latency_ms = (time.time() - start) * 1000

    return RetrievalResponse(
        query=query_data["original_query"],
        expanded_query=query_data["expanded_query"],
        results=[_build_chunk_result(r) for r in results],
        total_retrieved=len(results),
        latency_ms=round(latency_ms, 2),
    )


@router.post("/rerank", response_model=RerankResponse)
async def rerank_only(
    request: SearchRequest,
    current_user: User = Depends(get_current_user),
    query_svc: QueryService = Depends(get_query_service),
    retrieval_svc: RetrievalService = Depends(get_retrieval_service),
    fetch_svc: SolutionFetchService = Depends(get_solution_fetch_service),
    rerank_svc: ReRankService = Depends(get_rerank_service),
):
    start = time.time()

    query_data = await query_svc.prepare_query(
        query_text=request.query,
        expand=request.expand_query,
    )

    retrieval_results = await retrieval_svc.retrieve(
        dense_vector=query_data["dense_vector"],
        sparse_indices=query_data["sparse_indices"],
        sparse_values=query_data["sparse_values"],
    )

    fetched = await fetch_svc.fetch_solutions(retrieval_results)

    reranked = await rerank_svc.rerank(
        query=query_data["original_query"],
        candidates=fetched,
        top_k=request.top_k,
    )

    latency_ms = (time.time() - start) * 1000

    return RerankResponse(
        query=query_data["original_query"],
        reranked_chunks=[_build_chunk_result(c) for c in reranked],
        latency_ms=round(latency_ms, 2),
    )
