import faiss
import numpy as np
import pandas as pd

from rank_bm25 import BM25Okapi
from sentence_transformers import SentenceTransformer


# ============================================================
# LOAD FILES
# ============================================================

FAISS_INDEX_PATH = (
    "parquet_exports/ticket_similarity.index"
)

METADATA_PATH = (
    "parquet_exports/embedding_metadata.parquet"
)

BM25_PATH = (
    "parquet_exports/bm25_corpus.pkl"
)

EMBEDDING_MODEL_NAME = (
    "sentence-transformers/all-MiniLM-L6-v2"
)


# ============================================================
# LOAD COMPONENTS
# ============================================================

index = faiss.read_index(
    FAISS_INDEX_PATH
)

metadata_df = pd.read_parquet(
    METADATA_PATH
)

bm25_tokens = pd.read_pickle(
    BM25_PATH
)

bm25 = BM25Okapi(
    bm25_tokens.tolist()
)

embedding_model = SentenceTransformer(
    EMBEDDING_MODEL_NAME
)


# ============================================================
# BM25 SEARCH
# ============================================================

def bm25_search(
    query: str,
    top_k: int = 10
):

    tokenized_query = (
        query.lower().split()
    )

    scores = bm25.get_scores(
        tokenized_query
    )

    top_indices = np.argsort(scores)[::-1][:top_k]

    results = []

    for rank, idx in enumerate(top_indices):

        row = metadata_df.iloc[idx]

        results.append({
            "retriever": "bm25",
            "rank": rank + 1,
            "score": float(scores[idx]),
            "chunk_id": row["chunk_id"],
            "text": row["chunk_text"]
        })

    return pd.DataFrame(results)


# ============================================================
# FAISS SEARCH
# ============================================================

def faiss_search(
    query: str,
    top_k: int = 10
):

    query_embedding = embedding_model.encode(
        [query],
        convert_to_numpy=True,
        normalize_embeddings=True
    ).astype("float32")

    scores, indices = index.search(
        query_embedding,
        top_k
    )

    results = []

    for rank, (score, idx) in enumerate(
        zip(scores[0], indices[0])
    ):

        row = metadata_df.iloc[idx]

        results.append({
            "retriever": "faiss",
            "rank": rank + 1,
            "score": float(score),
            "chunk_id": row["chunk_id"],
            "text": row["chunk_text"]
        })

    return pd.DataFrame(results)


# ============================================================
# RRF
# ============================================================

def reciprocal_rank_fusion(
    result_frames,
    k: int = 60
):

    rrf_scores = {}

    text_lookup = {}

    for df in result_frames:

        for _, row in df.iterrows():

            chunk_id = row["chunk_id"]

            rank = row["rank"]

            score = 1 / (k + rank)

            if chunk_id not in rrf_scores:

                rrf_scores[chunk_id] = 0

            rrf_scores[chunk_id] += score

            text_lookup[chunk_id] = row["text"]

    fused_results = []

    for chunk_id, score in rrf_scores.items():

        fused_results.append({
            "chunk_id": chunk_id,
            "rrf_score": score,
            "text": text_lookup[chunk_id]
        })

    fused_df = pd.DataFrame(
        fused_results
    )

    fused_df = fused_df.sort_values(
        by="rrf_score",
        ascending=False
    )

    return fused_df.reset_index(drop=True)


# ============================================================
# HYBRID SEARCH
# ============================================================

def hybrid_search(
    query: str,
    top_k: int = 10
):

    bm25_df = bm25_search(
        query=query,
        top_k=top_k
    )

    faiss_df = faiss_search(
        query=query,
        top_k=top_k
    )

    fused_df = reciprocal_rank_fusion(
        [
            bm25_df,
            faiss_df
        ]
    )

    return fused_df.head(top_k)