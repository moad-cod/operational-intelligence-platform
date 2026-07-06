from fastapi import Depends, HTTPException, Request, status
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient
from sqlalchemy.ext.asyncio import AsyncSession

from app_v2.bm25_tokenizer import BM25Tokenizer
from app_v2.core.security import decode_token, oauth2_scheme
from app_v2.db.database import get_db
from app_v2.db.user_model import UserDB
from app_v2.db.user_repository import get_user_by_username
from app_v2.db.user_repository_class import UserRepository
from app_v2.vector_store import VectorStore


# ── Low-level infrastructure ─────────────────────────────

def get_qdrant_client(request: Request) -> QdrantClient:
    return request.app.state.app_state.qdrant_client


def get_vector_store(request: Request) -> VectorStore:
    return request.app.state.app_state.vector_store


def get_embedding_model(request: Request) -> SentenceTransformer:
    return request.app.state.app_state.embedding_model


def get_bm25_tokenizer(request: Request) -> BM25Tokenizer:
    return request.app.state.app_state.bm25_tokenizer


# ── Auth ─────────────────────────────────────────────────

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> UserDB:
    payload = decode_token(token)
    username: str | None = payload.get("sub")
    if username is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing subject claim",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user = await get_user_by_username(username, db)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


def get_user_repository(db: AsyncSession = Depends(get_db)) -> UserRepository:
    return UserRepository(db)


def get_auth_service(
    user_repo: UserRepository = Depends(get_user_repository),
) -> "AuthService":
    from app_v2.services.auth_service import AuthService
    return AuthService(user_repo)


# ── Search services ──────────────────────────────────────

def get_query_service(
    model: SentenceTransformer = Depends(get_embedding_model),
    tokenizer: BM25Tokenizer = Depends(get_bm25_tokenizer),
) -> "QueryService":
    from app_v2.services.query_service import QueryService
    return QueryService(model, tokenizer)


def get_retrieval_service(
    vector_store: VectorStore = Depends(get_vector_store),
) -> "RetrievalService":
    from app_v2.services.retrieval_service import RetrievalService
    return RetrievalService(vector_store)


def get_solution_fetch_service(
    vector_store: VectorStore = Depends(get_vector_store),
) -> "SolutionFetchService":
    from app_v2.services.solution_fetch_service import SolutionFetchService
    return SolutionFetchService(vector_store)


def get_rerank_service() -> "ReRankService":
    from app_v2.services.rerank_service import ReRankService
    return ReRankService()


def get_generation_service() -> "GenerationService":
    from app_v2.services.generation_service import GenerationService
    return GenerationService()
