import logging
from datetime import datetime

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app_v2.config import settings
from app_v2.core.lifespan import lifespan
from app_v2.db.database import AsyncSessionLocal
from app_v2.middleware import (
    LoggingMiddleware,
    RateLimitMiddleware,
    setup_logging,
)
from app_v2.routers.auth import router as auth_router
from app_v2.routers.registration import router as registration_router
from app_v2.routers.search import router as search_router

setup_logging()
logger = logging.getLogger(__name__)

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Hybrid RAG pipeline for IT incident resolution",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(RateLimitMiddleware)
app.add_middleware(LoggingMiddleware)

app.include_router(auth_router)
app.include_router(registration_router)
app.include_router(search_router)


@app.get("/health", tags=["System"])
async def health_check(request: Request) -> dict:
    try:
        qdrant_ok = await request.app.state.vector_store.health_check()
    except Exception:
        qdrant_ok = False

    try:
        model_ok = request.app.state.embedding_model is not None
    except Exception:
        model_ok = False

    try:
        bm25_ok = request.app.state.bm25_tokenizer is not None
    except Exception:
        bm25_ok = False

    try:
        async with AsyncSessionLocal() as session:
            await session.execute(text("SELECT 1"))
        db_ok = True
    except Exception:
        db_ok = False

    all_healthy = all([qdrant_ok, model_ok, bm25_ok, db_ok])

    return {
        "status": "healthy" if all_healthy else "degraded",
        "version": settings.APP_VERSION,
        "systems": {
            "qdrant": "ok" if qdrant_ok else "error",
            "embedding_model": "ok" if model_ok else "error",
            "bm25_tokenizer": "ok" if bm25_ok else "error",
            "database": "ok" if db_ok else "error",
        },
        "timestamp": datetime.utcnow().isoformat(),
    }


@app.get("/", tags=["System"])
async def root() -> dict:
    return {
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "docs": "/docs",
        "health": "/health",
    }


@app.exception_handler(Exception)
async def global_exception_handler(
    request: Request,
    exc: Exception,
) -> JSONResponse:
    logger.error(
        "Unhandled exception",
        extra={
            "path": request.url.path,
            "method": request.method,
            "request_id": getattr(request.state, "request_id", "unknown"),
            "error": str(exc),
        },
        exc_info=True,
    )
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "request_id": getattr(request.state, "request_id", "unknown"),
        },
    )
