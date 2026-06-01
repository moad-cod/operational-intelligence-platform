import pandas as pd
from sentence_transformers import CrossEncoder

from app.core.config import settings
from app.core.logging import logger


_reranker = None


def get_reranker():
    global _reranker
    if _reranker is None:
        logger.info("Loading CrossEncoder: %s", settings.cross_encoder_model)
        _reranker = CrossEncoder(settings.cross_encoder_model)
        logger.info("CrossEncoder loaded")
    return _reranker


def rerank_results(query: str, hybrid_df: pd.DataFrame, top_k: int = 5) -> pd.DataFrame:
    if hybrid_df.empty:
        logger.warning("Empty hybrid results — nothing to rerank")
        return hybrid_df

    reranker = get_reranker()

    pairs = [[query, row["text"]] for _, row in hybrid_df.iterrows()]
    scores = reranker.predict(pairs)

    results = hybrid_df.copy()
    results["rerank_score"] = scores
    results = results.sort_values(by="rerank_score", ascending=False)

    logger.info("Reranked %d results, returning top %d", len(results), top_k)
    return results.head(top_k).reset_index(drop=True)


def unload_reranker():
    global _reranker
    _reranker = None
    logger.info("CrossEncoder unloaded")
