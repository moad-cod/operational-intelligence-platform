import logging
import time

from sentence_transformers import SentenceTransformer
from fastapi import HTTPException, status

from app_v2.bm25_tokenizer import BM25Tokenizer

logger = logging.getLogger(__name__)

EXPANSION_MAP = {
    "not working": "not working failure error issue crashed down",
    "not connecting": "not connecting offline unreachable timeout network",
    "slow": "slow sluggish performance timeout latency delay",
    "error": "error failure exception issue problem",
    "crash": "crash failure freeze hang unresponsive",
    "access": "access login authentication permission credential",
    "SAP": "SAP system erp enterprise application",
    "VPN": "VPN remote access tunnel connection network",
    "email": "email mail outlook exchange communication",
    "password": "password credential login authentication security",
    "login": "login authentication access session credential",
    "network": "network connectivity connection internet",
    "server": "server backend host infrastructure service",
    "database": "database db sql data storage",
    "printer": "printer print printing device hardware",
    "update": "update upgrade patch version install",
    "install": "install setup deployment configuration installation",
    "permission": "permission access right authorization privilege",
}


class QueryService:

    def __init__(
        self,
        embedding_model: SentenceTransformer,
        bm25_tokenizer: BM25Tokenizer,
    ) -> None:
        self.embedding_model = embedding_model
        self.bm25_tokenizer = bm25_tokenizer

    async def prepare_query(
        self,
        query_text: str,
        expand: bool = True,
    ) -> dict:
        if not query_text or not query_text.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Query text must not be empty",
            )

        original = query_text.strip()
        expanded = self._expand_query(original) if expand else original

        start = time.time()
        dense_vector = self._embed(expanded)
        elapsed = (time.time() - start) * 1000
        if elapsed > 500:
            logger.info("Embedding took %.0fms", elapsed)

        sparse_indices, sparse_values = self._tokenize_sparse(original)

        return {
            "original_query": original,
            "expanded_query": expanded,
            "dense_vector": dense_vector,
            "sparse_indices": sparse_indices,
            "sparse_values": sparse_values,
        }

    def _expand_query(self, text: str) -> str:
        lower = text.lower()
        for phrase, replacement in EXPANSION_MAP.items():
            if phrase in lower:
                logger.debug("Expanding '%s' -> '%s'", phrase, replacement)
                return f"{text} {replacement}"
        return text

    def _embed(self, text: str) -> list[float]:
        vec = self.embedding_model.encode(text, normalize_embeddings=True)
        return vec.tolist()

    def _tokenize_sparse(
        self,
        text: str,
    ) -> tuple[list[int], list[float]]:
        return self.bm25_tokenizer.tokenize(text)
