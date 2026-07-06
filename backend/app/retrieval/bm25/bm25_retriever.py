import numpy as np
import pandas as pd
from rank_bm25 import BM25Okapi

from app.core.config import settings
from app.core.logging import logger


_bm25 = None
_bm25_tokens = None
_metadata_for_bm25 = None


def get_bm25():
    global _bm25, _bm25_tokens
    if _bm25 is None:
        path = settings.resolve_path(settings.bm25_corpus_path)
        logger.info("Loading BM25 corpus from %s", path)
        _bm25_tokens = pd.read_pickle(path)
        _bm25 = BM25Okapi(_bm25_tokens.tolist())
        logger.info("BM25 loaded: %d documents", len(_bm25_tokens))
    return _bm25


def get_bm25_metadata():
    global _metadata_for_bm25
    if _metadata_for_bm25 is None:
        from app.retrieval.faiss.faiss_retriever import get_metadata
        _metadata_for_bm25 = get_metadata()
    return _metadata_for_bm25


def bm25_search(query: str, top_k: int = 20) -> pd.DataFrame:
    bm25 = get_bm25()
    metadata_df = get_bm25_metadata()

    tokenized_query = query.lower().split()
    scores = bm25.get_scores(tokenized_query)
    top_indices = np.argsort(scores)[::-1][:top_k]

    results = []
    for rank, idx in enumerate(top_indices):
        row = metadata_df.iloc[idx]
        results.append({
            "retriever": "bm25",
            "rank": rank + 1,
            "score": float(scores[idx]),
            "chunk_id": row["chunk_id"],
            "text": row["chunk_text"],
        })

    return pd.DataFrame(results)


def unload_bm25():
    global _bm25, _bm25_tokens, _metadata_for_bm25
    _bm25 = None
    _bm25_tokens = None
    _metadata_for_bm25 = None
    logger.info("BM25 resources unloaded")
