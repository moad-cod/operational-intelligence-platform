from pydantic import BaseModel, Field


class MetadataFilter(BaseModel):
    priority_encoded: int | None = None


class SearchRequest(BaseModel):
    query: str = Field(min_length=3, max_length=1000)
    filters: MetadataFilter | None = None
    expand_query: bool = True
    top_k: int = Field(default=10, ge=1, le=60)


class ChunkResult(BaseModel):
    rag_id: str
    document_id: str
    chunk_text: str
    retrieval_score: float
    llm_score: float | None = None
    priority_encoded: int = 0
    metadata: dict = {}


class RetrievalResponse(BaseModel):
    query: str
    expanded_query: str
    results: list[ChunkResult]
    total_retrieved: int
    latency_ms: float


class SearchResponse(BaseModel):
    query: str
    expanded_query: str
    solution: str
    confidence: float
    sources: list[str]
    top_chunks: list[ChunkResult]
    tokens_used: int
    latency_ms: float


class RerankResponse(BaseModel):
    query: str
    reranked_chunks: list[ChunkResult]
    latency_ms: float
