import os
from pathlib import Path
from functools import lru_cache


class Settings:
    app_name: str = "AI Ticket Intelligence Platform"
    debug: bool = False

    groq_api_key: str = ""
    groq_model: str = "llama-3.3-70b-versatile"
    groq_temperature: float = 0.1
    groq_max_tokens: int = 1024

    embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2"
    cross_encoder_model: str = "cross-encoder/ms-marco-MiniLM-L-6-v2"

    faiss_index_path: str = "parquet_exports/ticket_similarity.index"
    metadata_path: str = "parquet_exports/embedding_metadata.parquet"
    bm25_corpus_path: str = "parquet_exports/bm25_corpus.pkl"

    xgb_priority_path: str = "models/xgb_priority_encoded.json"
    xgb_urgency_path: str = "models/xgb_urgency_encoded.json"
    xgb_impact_path: str = "models/xgb_impact_encoded.json"

    retrieval_top_k: int = 10
    bm25_top_k: int = 20
    faiss_top_k: int = 20
    rerank_top_k: int = 5
    rrf_k: int = 60

    escalation_threshold: float = 0.6
    context_token_limit: int = 4096

    backend_dir: Path = Path(__file__).resolve().parent.parent.parent

    def __init__(self):
        env_path = self.backend_dir / ".env"
        if env_path.exists():
            for line in env_path.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, val = line.partition("=")
                key = key.strip()
                val = val.strip().strip("\"'").strip()
                if not val:
                    val = ""
                os.environ.setdefault(key, val)

        for field_name in dir(self):
            if field_name.startswith("_"):
                continue
            env_val = os.environ.get(field_name.upper())
            if env_val is not None:
                current = getattr(self, field_name)
                if isinstance(current, bool):
                    setattr(self, field_name, env_val.lower() in ("1", "true", "yes"))
                elif isinstance(current, int):
                    setattr(self, field_name, int(env_val))
                elif isinstance(current, float):
                    setattr(self, field_name, float(env_val))
                else:
                    setattr(self, field_name, env_val)

        for path_field in ("faiss_index_path", "metadata_path", "bm25_corpus_path",
                           "xgb_priority_path", "xgb_urgency_path", "xgb_impact_path"):
            val = getattr(self, path_field)
            if val and not Path(val).is_absolute():
                setattr(self, path_field, str(self.backend_dir / val))

    def resolve_path(self, path: str) -> str:
        p = Path(path)
        return str(p if p.is_absolute() else self.backend_dir / p)


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
