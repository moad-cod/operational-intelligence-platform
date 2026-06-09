from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient

from app_v2.bm25_tokenizer import BM25Tokenizer
from app_v2.config import settings
from app_v2.db.database import init_db
from app_v2.vector_store import VectorStore, create_qdrant_client, verify_qdrant_connection


class AppState:
    def __init__(
        self,
        embedding_model: SentenceTransformer,
        qdrant_client: QdrantClient,
        vector_store: VectorStore,
        bm25_tokenizer: BM25Tokenizer,
    ) -> None:
        self.embedding_model = embedding_model
        self.qdrant_client = qdrant_client
        self.vector_store = vector_store
        self.bm25_tokenizer = bm25_tokenizer


def _log(msg: str) -> None:
    ts = datetime.now(timezone.utc).strftime("%H:%M:%S")
    print(f"[{ts}] [LIFESPAN] {msg}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── STARTUP ──────────────────────────────────────────
    # 0. Initialize database
    _log("Initializing database...")
    try:
        await init_db()
        _log("Database tables ready.")
    except Exception as exc:
        _log(f"Failed to initialize database: {exc}")
        raise

    # 1. Load embedding model
    _log(f"Loading embedding model: {settings.EMBEDDING_MODEL_NAME}...")
    try:
        embedding_model = SentenceTransformer(
            settings.EMBEDDING_MODEL_NAME
        )
        _log("Embedding model loaded successfully.")
    except Exception as exc:
        _log(f"Failed to load embedding model: {exc}")
        raise

    # 2. Connect Qdrant
    _log(f"Connecting to Qdrant at {settings.QDRANT_HOST}:{settings.QDRANT_PORT}...")
    try:
        qdrant_client = create_qdrant_client()
        verify_qdrant_connection(qdrant_client)
        vector_store = VectorStore(qdrant_client)
        _log("Qdrant connected and verified.")
    except Exception as exc:
        _log(
            f"Cannot connect to Qdrant at {settings.QDRANT_HOST}:{settings.QDRANT_PORT} "
            f"— startup aborted. {exc}"
        )
        raise

    # 3. Load BM25 tokenizer
    _log(f"Loading BM25 tokenizer from {settings.BM25_CORPUS_PATH}...")
    try:
        bm25_tokenizer = BM25Tokenizer(settings.BM25_CORPUS_PATH)
        _log("BM25 tokenizer loaded successfully.")
    except Exception as exc:
        _log(f"Failed to load BM25 tokenizer: {exc}")
        raise

    # 4. Store everything in app.state
    app.state.app_state = AppState(
        embedding_model=embedding_model,
        qdrant_client=qdrant_client,
        vector_store=vector_store,
        bm25_tokenizer=bm25_tokenizer,
    )

    _log("All systems ready")

    yield  # ← app runs here

    # ── SHUTDOWN ─────────────────────────────────────────
    _log("Shutting down...")
    qdrant_client.close()
    _log("Shutdown complete")
