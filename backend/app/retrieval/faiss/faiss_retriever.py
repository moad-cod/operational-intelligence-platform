import faiss
import numpy as np
import pandas as pd
from sentence_transformers import SentenceTransformer

from app.core.config import settings
from app.core.logging import logger


_faiss_index = None
_metadata_df = None
_embedding_model = None


def get_faiss_index():
    global _faiss_index
    if _faiss_index is None:
        path = settings.resolve_path(settings.faiss_index_path)
        logger.info("Loading FAISS index from %s", path)
        _faiss_index = faiss.read_index(path)
        logger.info("FAISS index loaded: %d vectors, dimension %d",
                     _faiss_index.ntotal, _faiss_index.d)
    return _faiss_index


def get_metadata():
    global _metadata_df
    if _metadata_df is None:
        path = settings.resolve_path(settings.metadata_path)
        logger.info("Loading metadata from %s", path)
        _metadata_df = pd.read_parquet(path)
        logger.info("Metadata loaded: %d rows", len(_metadata_df))
    return _metadata_df


def get_embedding_model():
    global _embedding_model
    if _embedding_model is None:
        logger.info("Loading embedding model: %s", settings.embedding_model)
        _embedding_model = SentenceTransformer(settings.embedding_model)
        logger.info("Embedding model loaded")
    return _embedding_model


def faiss_search(query: str, top_k: int = 20) -> pd.DataFrame:
    index = get_faiss_index()
    metadata_df = get_metadata()
    model = get_embedding_model()

    query_embedding = model.encode(
        [query],
        convert_to_numpy=True,
        normalize_embeddings=True
    ).astype("float32")

    scores, indices = index.search(query_embedding, top_k)

    results = []
    for rank, (score, idx) in enumerate(zip(scores[0], indices[0])):
        row = metadata_df.iloc[idx]
        results.append({
            "retriever": "faiss",
            "rank": rank + 1,
            "score": float(score),
            "chunk_id": row["chunk_id"],
            "text": row["chunk_text"],
        })

    return pd.DataFrame(results)


def unload_faiss():
    global _faiss_index, _metadata_df, _embedding_model
    _faiss_index = None
    _metadata_df = None
    _embedding_model = None
    logger.info("FAISS resources unloaded")
