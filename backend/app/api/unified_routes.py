from fastapi import APIRouter, HTTPException

from app.core.logging import logger
from app.core.config import settings
from app.shared.schemas.models import (
    HealthResponse,
    RetrieveRequest,
    RetrievedDoc,
    RetrieveResponse,
    RerankRequest,
    RerankedDoc,
    RerankResponse,
    RagRequest,
    RagResponse,
    TriageRequest,
    TriagePrediction,
    TriageResponse,
    CopilotRequest,
    CopilotResponse,
)
from app.retrieval.hybrid.hybrid_retriever import hybrid_search
from app.reranking.cross_encoder.reranker import rerank_results, get_reranker
from app.rag_pipeline.retrieval_pipeline import retrieve_rerank_generate
from app.triage.inference.triage_inference import predict_triage

router = APIRouter()


@router.get("/health", response_model=HealthResponse, tags=["Health"])
def health_check():
    components = {"api": "running"}

    grok_ok = bool(settings.groq_api_key)
    components["groq"] = "configured" if grok_ok else "missing key"

    try:
        get_reranker()
        components["crossencoder"] = "ready"
    except Exception as e:
        logger.warning("CrossEncoder not available: %s", e)
        components["crossencoder"] = "unavailable"

    try:
        from app.retrieval.faiss.faiss_retriever import get_faiss_index
        get_faiss_index()
        components["faiss"] = "ready"
    except Exception as e:
        logger.warning("FAISS not available: %s", e)
        components["faiss"] = "unavailable"

    status = "healthy" if "ready" in components.get("faiss", "") else "degraded"

    return HealthResponse(status=status, components=components)


@router.post("/retrieve", response_model=RetrieveResponse, tags=["Retrieval"])
def retrieve_endpoint(request: RetrieveRequest):
    try:
        hybrid_df = hybrid_search(query=request.query, top_k=request.top_k)
        results = [
            RetrievedDoc(
                chunk_id=row["chunk_id"],
                text=row["text"],
                score=float(row["rrf_score"]),
                retriever="hybrid",
            )
            for _, row in hybrid_df.iterrows()
        ]
        return RetrieveResponse(query=request.query, results=results, total=len(results))
    except Exception as e:
        logger.error("Retrieval failed: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/rerank", response_model=RerankResponse, tags=["Reranking"])
def rerank_endpoint(request: RerankRequest):
    try:
        hybrid_df = hybrid_search(query=request.query, top_k=request.top_k)
        reranked_df = rerank_results(query=request.query, hybrid_df=hybrid_df, top_k=request.top_k)

        results = [
            RerankedDoc(
                chunk_id=row["chunk_id"],
                text=row["text"],
                hybrid_score=float(row.get("rrf_score", 0)),
                rerank_score=float(row["rerank_score"]),
            )
            for _, row in reranked_df.iterrows()
        ]
        return RerankResponse(query=request.query, results=results, total=len(results))
    except Exception as e:
        logger.error("Reranking failed: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/rag", response_model=RagResponse, tags=["RAG"])
def rag_endpoint(request: RagRequest):
    try:
        response, context_docs, _ = retrieve_rerank_generate(
            query=request.query,
            top_k_retrieval=request.top_k_retrieval,
            top_k_rerank=request.top_k_rerank,
        )
        docs = [
            RetrievedDoc(
                chunk_id=d["chunk_id"],
                text=d["text"],
                score=d["score"],
                retriever=d["retriever"],
            )
            for d in context_docs
        ]
        return RagResponse(query=request.query, response=response, context_docs=docs)
    except Exception as e:
        logger.error("RAG pipeline failed: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/triage", response_model=TriageResponse, tags=["Triage"])
def triage_endpoint(request: TriageRequest):
    try:
        features = request.model_dump()
        features.pop("ticket_pk", None)
        result = predict_triage(features)

        return TriageResponse(
            predictions=TriagePrediction(
                priority=result["priority"],
                urgency=result["urgency"],
                impact=result["impact"],
                priority_label=result["priority_label"],
                urgency_label=result["urgency_label"],
                impact_label=result["impact_label"],
            ),
            escalation_risk=result["escalation_risk"],
            should_escalate=result["should_escalate"],
        )
    except Exception as e:
        logger.error("Triage failed: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/copilot", response_model=CopilotResponse, tags=["Copilot"])
def copilot_endpoint(request: CopilotRequest):
    try:
        avg_features = {
            "text_word_count": 50.0,
            "text_char_count": 300.0,
            "avg_word_length": 5.5,
            "special_char_ratio": 0.03,
            "text_complexity_score": 4.0,
            "retrieval_quality_score": 0.75,
            "corpus_quality_score": 0.75,
            "similarity_confidence": 0.75,
        }

        response, context_docs, _ = retrieve_rerank_generate(
            query=request.query,
            top_k_retrieval=10,
            top_k_rerank=5,
        )

        result = predict_triage(avg_features)

        docs = [
            RetrievedDoc(
                chunk_id=d["chunk_id"],
                text=d["text"],
                score=d["score"],
                retriever=d["retriever"],
            )
            for d in context_docs
        ]

        return CopilotResponse(
            query=request.query,
            triage=TriagePrediction(
                priority=result["priority"],
                urgency=result["urgency"],
                impact=result["impact"],
                priority_label=result["priority_label"],
                urgency_label=result["urgency_label"],
                impact_label=result["impact_label"],
            ),
            escalation_risk=result["escalation_risk"],
            should_escalate=result["should_escalate"],
            rag_response=response,
            context_docs=docs,
        )
    except Exception as e:
        logger.error("Copilot failed: %s", e)
        raise HTTPException(status_code=500, detail=str(e))
