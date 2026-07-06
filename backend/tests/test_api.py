from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root():
    resp = client.get("/")
    assert resp.status_code == 200
    data = resp.json()
    assert "message" in data


def test_health():
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] in ("healthy", "degraded")
    assert "faiss" in data["components"]


def test_retrieve():
    resp = client.post("/retrieve", json={"query": "password reset", "top_k": 3})
    assert resp.status_code == 200
    data = resp.json()
    assert data["query"] == "password reset"
    assert len(data["results"]) <= 3
    if data["results"]:
        assert "chunk_id" in data["results"][0]
        assert "text" in data["results"][0]


def test_retrieve_empty_query():
    resp = client.post("/retrieve", json={"query": "", "top_k": 3})
    assert resp.status_code == 422


def test_rerank():
    resp = client.post("/rerank", json={"query": "network issue", "top_k": 3})
    assert resp.status_code == 200
    data = resp.json()
    assert data["query"] == "network issue"


def test_triage():
    payload = {
        "text_word_count": 50,
        "text_char_count": 300,
        "avg_word_length": 5.5,
        "special_char_ratio": 0.03,
        "text_complexity_score": 4.2,
        "retrieval_quality_score": 0.8,
        "corpus_quality_score": 0.75,
        "similarity_confidence": 0.7,
    }
    resp = client.post("/triage", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert "predictions" in data
    assert "escalation_risk" in data
    assert data["predictions"]["priority"] in (2, 3, 4, 5)


def test_rag():
    resp = client.post("/rag", json={"query": "how to reset password", "top_k_retrieval": 5, "top_k_rerank": 3})
    assert resp.status_code == 200
    data = resp.json()
    assert "response" in data
    assert "context_docs" in data


def test_copilot():
    resp = client.post("/copilot", json={"query": "server down"})
    assert resp.status_code == 200
    data = resp.json()
    assert "rag_response" in data
    assert "triage" in data
    assert "should_escalate" in data