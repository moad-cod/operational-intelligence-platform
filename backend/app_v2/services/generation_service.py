import asyncio
import json
import logging

from fastapi import HTTPException, status
from groq import Groq

from app_v2.config import settings

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = (
    "You are an expert IT support assistant.\n"
    "You resolve technical incidents using the provided solution chunks.\n"
    "Always respond in this exact JSON format:\n"
    "{\n"
    '  "solution": "step by step resolution here",\n'
    '  "confidence": 0.0 to 1.0\n'
    "}"
)

GENERATION_TIMEOUT = 30


class GenerationService:

    def __init__(self) -> None:
        self.client = Groq(api_key=settings.GROQ_API_KEY)
        self.model = settings.GROQ_MODEL_NAME

    async def generate(
        self,
        query: str,
        reranked_chunks: list[dict],
    ) -> dict:
        if not reranked_chunks:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No relevant context available to generate a solution",
            )

        context = self._build_context(reranked_chunks)
        logger.info(
            "Generating solution from %d chunks (context length: %d chars)...",
            len(reranked_chunks), len(context),
        )

        raw = await self._call_groq(SYSTEM_PROMPT, context, query)

        try:
            parsed = json.loads(raw)
            solution = parsed.get("solution", raw)
            confidence = float(parsed.get("confidence", 0.5))
        except (json.JSONDecodeError, TypeError, ValueError):
            logger.warning("Failed to parse Groq JSON response, using raw text")
            solution = raw
            confidence = 0.0

        confidence = max(0.0, min(1.0, confidence))
        sources = [c.get("rag_id", "") for c in reranked_chunks if c.get("rag_id")]

        return {
            "solution": solution,
            "confidence": confidence,
            "sources": sources,
            "tokens_used": 0,
        }

    def _build_context(self, chunks: list[dict]) -> str:
        parts = []
        total = 0
        max_chars = int(settings.GROQ_MAX_TOKENS * 0.7 * 4)

        for i, c in enumerate(chunks):
            text = c.get("chunk_text", "")
            score = c.get("llm_score", c.get("retrieval_quality_score", 0.0))
            block = (
                f"--- Source {i + 1} (score: {score:.2f}) ---\n"
                f"{text}\n"
            )
            total += len(block)
            if total > max_chars:
                logger.info("Context truncated at source %d/%d", i + 1, len(chunks))
                break
            parts.append(block)

        return "\n".join(parts)

    async def _call_groq(
        self,
        system_prompt: str,
        context: str,
        query: str,
    ) -> str:
        user_prompt = f"Incident query: {query}\n\nRelevant solution context:\n{context}\n\nGenerate the resolution:"

        async def _do_call() -> str:
            return await asyncio.to_thread(
                self.client.chat.completions.create,
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                temperature=settings.GROQ_TEMPERATURE,
                max_tokens=settings.GROQ_MAX_TOKENS,
                response_format={"type": "json_object"},
            )

        try:
            response = await asyncio.wait_for(_do_call(), timeout=GENERATION_TIMEOUT)
        except asyncio.TimeoutError:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="LLM generation timed out",
            )

        content = response.choices[0].message.content.strip()
        usage = response.usage
        if usage:
            logger.info(
                "Groq tokens — prompt: %d, completion: %d, total: %d",
                usage.prompt_tokens, usage.completion_tokens, usage.total_tokens,
            )

        return content
