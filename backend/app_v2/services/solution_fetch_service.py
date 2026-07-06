import asyncio
import logging

from app_v2.vector_store import VectorStore

logger = logging.getLogger(__name__)


class SolutionFetchService:

    def __init__(self, vector_store: VectorStore) -> None:
        self.vector_store = vector_store

    async def fetch_solutions(
        self,
        retrieval_results: list[dict],
    ) -> list[dict]:
        if not retrieval_results:
            return []

        rag_ids = []
        seen = set()
        for r in retrieval_results:
            rid = r.get("rag_id")
            if rid and rid not in seen:
                seen.add(rid)
                rag_ids.append(rid)

        logger.info("Fetching %d unique solutions by rag_id...", len(rag_ids))
        fetched = await asyncio.to_thread(
            self.vector_store.fetch_by_rag_ids, rag_ids
        )

        payload_map: dict[str, dict] = {}
        for f in fetched:
            payload_map[f["rag_id"]] = f

        enriched = []
        for r in retrieval_results:
            rid = r.get("rag_id", "")
            payload = payload_map.get(rid, {})
            enriched.append({
                "rag_id": rid,
                "document_id": payload.get("document_id", ""),
                "chunk_text": payload.get("chunk_text", ""),
                "retrieval_score": r.get("score", 0.0),
                "retrieval_quality_score": payload.get(
                    "retrieval_quality_score", 0.0
                ),
                "priority_encoded": payload.get("priority_encoded", 0),
                "metadata": payload.get("metadata", {}),
            })

        return enriched
