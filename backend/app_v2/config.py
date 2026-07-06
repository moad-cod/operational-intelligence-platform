from pathlib import Path

from pydantic import field_validator, Field
from pydantic_settings import BaseSettings, SettingsConfigDict

import json


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # ── Qdrant ──────────────────────────────────────────────
    QDRANT_HOST: str = Field(default="localhost")
    QDRANT_PORT: int = Field(default=6333)
    QDRANT_COLLECTION_NAME: str = Field(default="incident_resolution")

    # ── Embedding ───────────────────────────────────────────
    EMBEDDING_MODEL_NAME: str = Field(
        default="sentence-transformers/all-MiniLM-L6-v2"
    )
    EMBEDDING_VECTOR_DIM: int = Field(default=384)

    # ── BM25 ────────────────────────────────────────────────
    BM25_CORPUS_PATH: str = Field(default="parquet_exports_v2/bm25_corpus_v2.pkl")
    BM25_SPARSE_TOP_K: int = Field(default=60)

    # ── Retrieval ───────────────────────────────────────────
    DENSE_TOP_K: int = Field(default=60)
    HYBRID_TOP_K: int = Field(default=60)
    RERANK_TOP_K: int = Field(default=10)

    # ── Database ─────────────────────────────────────────────
    DATABASE_URL: str = Field(default="sqlite+aiosqlite:///./app_v2/db/users.db")

    # ── Groq (LLM) ───────────────────────────────────────────
    GROQ_API_KEY: str = Field(...)
    GROQ_MODEL_NAME: str = Field(default="llama-3.3-70b-versatile")
    GROQ_BASE_URL: str = Field(default="https://api.groq.com/openai/v1")
    GROQ_MAX_TOKENS: int = Field(default=1024)
    GROQ_TEMPERATURE: float = Field(default=0.2)

    # ── JWT ─────────────────────────────────────────────────
    JWT_SECRET_KEY: str = Field(...)
    JWT_ALGORITHM: str = Field(default="HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=30)
    REFRESH_TOKEN_EXPIRE_DAYS: int = Field(default=7)

    # ── Middleware ───────────────────────────────────────────
    RATE_LIMIT_ENABLED: bool = Field(default=True)

    # ── App ─────────────────────────────────────────────────
    APP_NAME: str = Field(default="IncidentResolutionAPI")
    APP_VERSION: str = Field(default="2.0.0")
    DEBUG: bool = Field(default=False)
    ALLOWED_ORIGINS: list[str] = Field(default=["http://localhost:3000"])

    # ── Validators ──────────────────────────────────────────

    @field_validator("JWT_SECRET_KEY")
    @classmethod
    def jwt_secret_min_length(cls, v: str) -> str:
        if len(v) < 32:
            raise ValueError(
                f"JWT_SECRET_KEY must be at least 32 characters (got {len(v)})"
            )
        return v

    @field_validator("GROQ_API_KEY")
    @classmethod
    def groq_key_must_not_be_empty(cls, v: str) -> str:
        if not v or v.strip() == "" or v == "your_groq_key_here":
            raise ValueError("GROQ_API_KEY is required")
        return v

    @field_validator("QDRANT_PORT")
    @classmethod
    def qdrant_port_range(cls, v: int) -> int:
        if not 1 <= v <= 65535:
            raise ValueError(f"QDRANT_PORT must be between 1 and 65535 (got {v})")
        return v

    @field_validator("BM25_CORPUS_PATH")
    @classmethod
    def bm25_corpus_must_exist(cls, v: str) -> str:
        if not Path(v).exists():
            raise ValueError(f"BM25 corpus not found at: {v}")
        return v

    @field_validator("EMBEDDING_VECTOR_DIM")
    @classmethod
    def embedding_dim_must_match(cls, v: int) -> int:
        if v != 384:
            raise ValueError(
                f"EMBEDDING_VECTOR_DIM must equal 384 to match uploaded vectors "
                f"(got {v})"
            )
        return v

    @field_validator("RERANK_TOP_K")
    @classmethod
    def rerank_less_than_hybrid(cls, v: int, info) -> int:
        hybrid = info.data.get("HYBRID_TOP_K")
        if hybrid is not None and v >= hybrid:
            raise ValueError(
                f"RERANK_TOP_K ({v}) must be less than HYBRID_TOP_K ({hybrid})"
            )
        return v

    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def parse_allowed_origins(cls, v):
        if isinstance(v, str):
            return json.loads(v)
        return v

    @field_validator("DEBUG", mode="before")
    @classmethod
    def parse_debug(cls, v):
        if isinstance(v, str):
            return v.lower() in ("true", "1", "yes")
        return v

    @field_validator("ACCESS_TOKEN_EXPIRE_MINUTES")
    @classmethod
    def positive_expire_minutes(cls, v: int) -> int:
        if v < 1:
            raise ValueError(
                f"ACCESS_TOKEN_EXPIRE_MINUTES must be positive (got {v})"
            )
        return v

    @field_validator("REFRESH_TOKEN_EXPIRE_DAYS")
    @classmethod
    def positive_expire_days(cls, v: int) -> int:
        if v < 1:
            raise ValueError(
                f"REFRESH_TOKEN_EXPIRE_DAYS must be positive (got {v})"
            )
        return v


settings = Settings()
