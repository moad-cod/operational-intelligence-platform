from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.logging import setup_logging, logger
from app.api.unified_routes import router


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging(debug=settings.debug)
    logger.info("Starting %s", settings.app_name)
    try:
        from app.retrieval.faiss.faiss_retriever import get_faiss_index
        logger.info("Pre-loading FAISS index...")
        get_faiss_index()
    except Exception as e:
        logger.warning("FAISS pre-load failed: %s", e)
    try:
        from app.retrieval.bm25.bm25_retriever import get_bm25
        logger.info("Pre-loading BM25...")
        get_bm25()
    except Exception as e:
        logger.warning("BM25 pre-load failed: %s", e)
    yield
    logger.info("Shutting down %s", settings.app_name)
    from app.retrieval.faiss.faiss_retriever import unload_faiss
    from app.retrieval.bm25.bm25_retriever import unload_bm25
    from app.reranking.cross_encoder.reranker import unload_reranker
    from app.triage.inference.triage_inference import unload_triage
    unload_faiss()
    unload_bm25()
    unload_reranker()
    unload_triage()


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)


@app.get("/")
def root():
    return {"message": f"{settings.app_name} API Running"}
