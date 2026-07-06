from pydantic import BaseModel, Field
from typing import Optional


class HealthResponse(BaseModel):
    status: str
    components: dict[str, str]


class RetrieveRequest(BaseModel):
    query: str = Field(..., min_length=1, description="Search query")
    top_k: int = Field(default=10, ge=1, le=50, description="Number of results")


class RetrievedDoc(BaseModel):
    chunk_id: str
    text: str
    score: float
    retriever: str


class RetrieveResponse(BaseModel):
    query: str
    results: list[RetrievedDoc]
    total: int


class RerankRequest(BaseModel):
    query: str = Field(..., min_length=1)
    top_k: int = Field(default=5, ge=1, le=20)


class RerankedDoc(BaseModel):
    chunk_id: str
    text: str
    hybrid_score: float
    rerank_score: float


class RerankResponse(BaseModel):
    query: str
    results: list[RerankedDoc]
    total: int


class RagRequest(BaseModel):
    query: str = Field(..., min_length=1)
    top_k_retrieval: int = Field(default=10, ge=1, le=50)
    top_k_rerank: int = Field(default=5, ge=1, le=20)


class RagResponse(BaseModel):
    query: str
    response: str
    context_docs: list[RetrievedDoc]


class TriageRequest(BaseModel):
    ticket_pk: Optional[str] = None
    text_word_count: float
    text_char_count: float
    avg_word_length: float
    special_char_ratio: float
    text_complexity_score: float
    retrieval_quality_score: float
    corpus_quality_score: float
    similarity_confidence: float


class TriagePrediction(BaseModel):
    priority: int
    urgency: int
    impact: int
    priority_label: str
    urgency_label: str
    impact_label: str


class TriageResponse(BaseModel):
    predictions: TriagePrediction
    escalation_risk: float
    should_escalate: bool


class CopilotRequest(BaseModel):
    query: str = Field(..., min_length=1)


class CopilotResponse(BaseModel):
    query: str
    triage: TriagePrediction
    escalation_risk: float
    should_escalate: bool
    rag_response: str
    context_docs: list[RetrievedDoc]
