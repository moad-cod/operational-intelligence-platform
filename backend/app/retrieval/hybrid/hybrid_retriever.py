import pandas as pd

from app.core.config import settings
from app.core.logging import logger
from app.retrieval.faiss.faiss_retriever import faiss_search
from app.retrieval.bm25.bm25_retriever import bm25_search


def reciprocal_rank_fusion(result_frames: list[pd.DataFrame], k: int = 60) -> pd.DataFrame:
    rrf_scores = {}
    text_lookup = {}

    for df in result_frames:
        for _, row in df.iterrows():
            chunk_id = row["chunk_id"]
            rank = row["rank"]
            score = 1.0 / (k + rank)

            if chunk_id not in rrf_scores:
                rrf_scores[chunk_id] = 0.0
            rrf_scores[chunk_id] += score
            text_lookup[chunk_id] = row["text"]

    fused_results = [
        {"chunk_id": cid, "rrf_score": sc, "text": text_lookup[cid]}
        for cid, sc in rrf_scores.items()
    ]

    fused_df = pd.DataFrame(fused_results)
    fused_df = fused_df.sort_values(by="rrf_score", ascending=False)
    return fused_df.reset_index(drop=True)


def hybrid_search(query: str, top_k: int = 10) -> pd.DataFrame:
    logger.info("Hybrid search: query='%s', top_k=%d", query[:80], top_k)

    bm25_df = bm25_search(query=query, top_k=top_k)
    faiss_df = faiss_search(query=query, top_k=top_k)

    fused_df = reciprocal_rank_fusion([bm25_df, faiss_df], k=settings.rrf_k)
    result = fused_df.head(top_k)

    logger.info("Hybrid search returned %d results", len(result))
    return result
