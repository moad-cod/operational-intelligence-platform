import pandas as pd

from app.core.config import settings
from app.core.logging import logger


def build_context(reranked_df: pd.DataFrame) -> str:
    if reranked_df.empty:
        logger.warning("Empty reranked results — returning empty context")
        return ""

    seen_ids = set()
    chunks = []
    token_estimate = 0

    for _, row in reranked_df.iterrows():
        chunk_id = row.get("chunk_id", "unknown")
        text = str(row.get("text", ""))

        if not text.strip():
            logger.debug("Skipping empty text for chunk %s", chunk_id)
            continue

        if chunk_id in seen_ids:
            logger.debug("Skipping duplicate chunk %s", chunk_id)
            continue
        seen_ids.add(chunk_id)

        # rough token estimate: 1 token ~ 4 chars
        estimated_tokens = len(text) // 4
        if token_estimate + estimated_tokens > settings.context_token_limit:
            logger.debug("Token limit reached at chunk %s", chunk_id)
            break

        chunks.append(f"[Document] (ID: {chunk_id})\n{text}")
        token_estimate += estimated_tokens

    context = "\n\n---\n\n".join(chunks)
    logger.info("Context built: %d chunks, ~%d estimated tokens", len(chunks), token_estimate)
    return context
