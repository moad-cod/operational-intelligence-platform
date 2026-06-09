import asyncio
import logging
import re

from groq import Groq

from app_v2.config import settings

logger = logging.getLogger(__name__)

RERANK_SYSTEM_PROMPT = (
    "You are a relevance scoring assistant for IT support tickets.\n"
    "You respond with a single float between 0.0 and 1.0 only.\n"
    "No explanation. No extra text. Just the number."
)


class ReRankService:

    def __init__(self) -> None:
        self.client = Groq(api_key=settings.GROQ_API_KEY)
        self.model = settings.GROQ_MODEL_NAME

    async def rerank(
        self,
        query: str,
        candidates: list[dict],
        top_k: int = settings.RERANK_TOP_K,
    ) -> list[dict]:
        if not candidates:
            return []

        logger.info("Reranking %d candidates...", len(candidates))

        try:
            tasks = [
                self._score_candidate(query, c["chunk_text"])
                for c in candidates
            ]
            scores = await asyncio.gather(*tasks)

            for candidate, score in zip(candidates, scores):
                candidate["llm_score"] = score

            ranked = sorted(candidates, key=lambda x: x["llm_score"], reverse=True)
            kept = ranked[:top_k]
            dropped = [c["rag_id"] for c in ranked[top_k:]]
            if dropped:
                logger.debug("Dropped %d candidates: %s", len(dropped), dropped)

        except Exception as exc:
            logger.warning(
                "Groq reranking failed (%s), falling back to "
                "retrieval_quality_score", exc
            )
            ranked = sorted(
                candidates,
                key=lambda x: x.get("retrieval_quality_score", 0.0),
                reverse=True,
            )
            for c in ranked:
                c["llm_score"] = c.get("retrieval_quality_score", 0.0)
            kept = ranked[:top_k]

        logger.info("Reranking complete: %d kept, top score=%.4f",
                     len(kept), kept[0]["llm_score"] if kept else 0.0)
        return kept

    async def _score_candidate(
        self,
        query: str,
        chunk_text: str,
    ) -> float:
        try:
            response = await asyncio.to_thread(
                self.client.chat.completions.create,
                model=self.model,
                messages=[
                    {"role": "system", "content": RERANK_SYSTEM_PROMPT},
                    {
                        "role": "user",
                        "content": (
                            f"Query: {query}\n\n"
                            f"Solution chunk:\n{chunk_text}\n\n"
                            f"Relevance score (0.0 = completely irrelevant, "
                            f"1.0 = perfect match):"
                        ),
                    },
                ],
                temperature=0.0,
                max_tokens=10,
            )
            raw = response.choices[0].message.content.strip()
            match = re.search(r"(\d+\.?\d*)", raw)
            if match:
                score = float(match.group(1))
                return max(0.0, min(1.0, score))
            return 0.0
        except Exception as exc:
            logger.debug("Score failed for chunk: %s", exc)
            return 0.0
