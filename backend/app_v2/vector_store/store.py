import logging

from fastapi import HTTPException, status
from qdrant_client import QdrantClient
from qdrant_client.http.models import (
    FieldCondition,
    Filter,
    Fusion,
    FusionQuery,
    MatchValue,
    Prefetch,
    ScoredPoint,
    SparseVector,
)

from app_v2.config import settings

logger = logging.getLogger(__name__)

PAYLOAD_FIELDS = [
    "chunk_id",
    "document_id",
    "rag_id",
    "chunk_text",
    "retrieval_quality_score",
    "priority_encoded",
    "metadata_json",
]


def _scored_to_dict(point: ScoredPoint) -> dict:
    payload = point.payload or {}
    metadata_raw = payload.get("metadata_json")
    return {
        "score": point.score,
        "chunk_id": payload.get("chunk_id", ""),
        "document_id": payload.get("document_id", ""),
        "rag_id": payload.get("rag_id", ""),
        "chunk_text": payload.get("chunk_text", ""),
        "retrieval_quality_score": payload.get("retrieval_quality_score", 0.0),
        "priority_encoded": payload.get("priority_encoded", 0),
        "metadata": metadata_raw if isinstance(metadata_raw, dict) else {},
    }


class VectorStore:

    def __init__(self, client: QdrantClient):
        self.client = client
        self.collection = settings.QDRANT_COLLECTION_NAME

    def hybrid_search(
        self,
        dense_vector: list[float],
        sparse_indices: list[int],
        sparse_values: list[float],
        metadata_filter: dict | None = None,
        dense_top_k: int = settings.DENSE_TOP_K,
        sparse_top_k: int = settings.BM25_SPARSE_TOP_K,
        hybrid_top_k: int = settings.HYBRID_TOP_K,
    ) -> list[dict]:
        qdrant_filter = None
        if metadata_filter:
            conditions = [
                FieldCondition(
                    key=f"metadata_json.{key}",
                    match=MatchValue(value=value),
                )
                for key, value in metadata_filter.items()
            ]
            qdrant_filter = Filter(must=conditions)

        prefetch = [
            Prefetch(
                query=SparseVector(indices=sparse_indices, values=sparse_values),
                using="bm25",
                limit=sparse_top_k,
            ),
            Prefetch(
                query=dense_vector,
                using="dense",
                filter=qdrant_filter,
                limit=dense_top_k,
            ),
        ]

        try:
            results = self.client.query_points(
                collection_name=self.collection,
                prefetch=prefetch,
                query=FusionQuery(fusion=Fusion.RRF),
                limit=hybrid_top_k,
                with_payload=PAYLOAD_FIELDS,
            )
        except Exception as exc:
            logger.error("Qdrant hybrid_search failed: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Search service unavailable",
            ) from exc

        return [_scored_to_dict(p) for p in results.points]

    def fetch_by_rag_ids(
        self,
        rag_ids: list[str],
    ) -> list[dict]:
        if not rag_ids:
            return []

        qdrant_filter = Filter(
            should=[
                FieldCondition(
                    key="rag_id",
                    match=MatchValue(value=rid),
                )
                for rid in rag_ids
            ]
        )

        try:
            results, _ = self.client.scroll(
                collection_name=self.collection,
                scroll_filter=qdrant_filter,
                limit=len(rag_ids),
                with_payload=PAYLOAD_FIELDS,
            )
        except Exception as exc:
            logger.error("Qdrant fetch_by_rag_ids failed: %s", exc)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Fetch service unavailable",
            ) from exc

        return [_scored_to_dict(p) for p in results]

    def health_check(self) -> bool:
        try:
            self.client.get_collection(self.collection)
            return True
        except Exception:
            return False
