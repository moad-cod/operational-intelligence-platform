import asyncio
import logging
import time

from app_v2.vector_store import VectorStore

logger = logging.getLogger(__name__)


class RetrievalService:

    def __init__(self, vector_store: VectorStore) -> None:
        self.vector_store = vector_store

    async def retrieve(
        self,
        dense_vector: list[float],
        sparse_indices: list[int],
        sparse_values: list[float],
        metadata_filter: dict | None = None,
    ) -> list[dict]:
        logger.info("Starting hybrid retrieval...")
        start = time.time()

        results = await asyncio.to_thread(
            self.vector_store.hybrid_search,
            dense_vector,
            sparse_indices,
            sparse_values,
            metadata_filter,
        )

        elapsed = (time.time() - start) * 1000
        if not results:
            logger.warning(
                "Hybrid retrieval returned 0 results in %.0fms", elapsed
            )
            return []

        logger.info("Retrieved %d results in %.0fms", len(results), elapsed)
        return results
