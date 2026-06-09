# AI Ticket Intelligence Platform — PROJECT MAP (ACCURATE)

> **Last Updated:** 2026-06-06  
> **Source of Truth:** Actual code in `backend/` — not planned features.

---

## [TECH_STACK]

| Component              | Version               |
|------------------------|-----------------------|
| Python                 | 3.12                  |
| sentence-transformers  | 3.4.1                 |
| FAISS (cpu)            | 1.14.2                |
| rank-bm25              | 0.2.2                 |
| torch                  | 2.12.0 (CPU only)     |
| transformers           | — (required by ST)    |
| groq                   | 1.2.0                 |
| ragas                  | 0.2.x (not wired)     |
| FastAPI                | 0.136+                |
| uvicorn                | 0.48+                 |
| LangChain              | NOT USED              |
| LlamaIndex             | NOT USED              |
| CrossEncoder           | ms-marco-MiniLM-L-6-v2 |
| LLM (Groq)             | llama-3.3-70b-versatile |
| XGBoost                | multi-class classifiers (priority/urgency/impact) |

---

## [SYSTEM_FLOW]

```
source_data/
    ↓
01_data_understanding.ipynb  →  data_understanding_report.csv
02_data_cleaning.ipynb
03_eda_visualization.ipynb   →  eda_summary.csv
04_feature_engineering.ipynb →  feature_dataset_sample.csv
05_retrieval_preparation.ipynb → retrieval_ready_sample.csv
    ↓
parquet_exports/retrieval_ready_dataset.parquet
    ↓
06_embedding_pipeline.ipynb
    ↓
parquet_exports/
├── ticket_similarity.index   (FAISS, 230,088 × 384, cosine)
├── embeddings.npy             (raw float32 embeddings)
├── embedding_metadata.parquet (230,088 rows, 9 cols)
├── bm25_corpus.pkl            (tokenized corpus, 230,088 docs)
└── retrieval_ready_dataset.parquet
    ↓
07_hybrid_retrieval.ipynb
├── FAISS dense retrieval  (all-MiniLM-L6-v2, top_k=20)
├── BM25 sparse retrieval  (top_k=20)
├── RRF fusion             (k=60)
└── hybrid_search(query, top_k=10)
    ↓  evaluation/hybrid_retrieval_results.csv
    ↓
08_reranking_pipeline.ipynb  ✅ PRODUCTIONIZED
├── CrossEncoder reranking   (ms-marco-MiniLM-L-6-v2)
├── retrieve_and_rerank()    (hybrid → rerank)
├── Latency benchmarking      (avg 410ms retrieval, 623ms rerank)
├── Context validation        (all PASS)
├── Multi-query validation    (10/10 queries OK)
├── Error handling + logging
└── Exports → evaluation/reranking_results.csv
              evaluation/benchmarks/reranking_latency.csv
    ↓
09_rag_generation_pipeline.ipynb  ✅ PRODUCTIONIZED
├── Hybrid retrieval          (FAISS + BM25 + RRF)
├── CrossEncoder reranking    (ms-marco-MiniLM-L-6-v2)
├── Context builder           (structured, validated, deduped)
├── Prompt template           (system + context + question)
├── Groq generation           (llama-3.3-70b-versatile)
├── Hallucination guard       (context-grounded responses)
├── Latency benchmarking      (avg 358ms retrieval, 370ms rerank, 1091ms gen)
├── Multi-query validation    (10/10 queries OK)
├── Error handling + logging
└── Exports → evaluation/rag_pipeline_results.csv
              evaluation/benchmarks/rag_latency.csv
              evaluation/sample_rag_response.txt
    ↓  (feature_engineered_dataset.parquet)
    ├──→ 10_triage_classification_pipeline.ipynb  ✅ PRODUCTIONIZED
│   ├── LabelEncoder target encoding
│   ├── Train/test split                    (stratified, 75/25)
│   ├── XGBoost multi-class classifiers     (3 models: priority, urgency, impact)
│   ├── Escalation risk scoring             (weighted composite + threshold)
│   ├── E2E prediction pipeline             (predict_triage() with inverse transform)
│   ├── Feature importance analysis
│   ├── Error handling + structured logging
│   └── Exports → models/xgb_*.json       (3 models)
│                 evaluation/triage_metrics.csv
│                 evaluation/triage_report.txt
│                 evaluation/feature_importance.csv
    ↓
evaluation/
├── hybrid_retrieval_results.csv   ✅
├── reranking_results.csv          ✅
├── rag_pipeline_results.csv       ✅
├── sample_rag_response.txt        ✅
├── triage_metrics.csv             ✅
├── triage_report.txt              ✅
├── feature_importance.csv         ✅
├── benchmarks/
│   ├── reranking_latency.csv      ✅
│   └── rag_latency.csv            ✅
├── ragas/                 ❌ empty
├── retrieval/             ❌ empty
├── data_understanding_report_v2.csv  ✅ (V2)
├── eda_summary_v2.csv               ✅ (V2)
├── retrieval_ready_v2_sample.csv     ✅ (V2)
├── feature_dataset_sample_v2.csv     ✅ (V2)
└── evaluation_v2/                    ❌ empty directory
```

---

## [RAG_ARCHITECTURE]

### Full RAG Pipeline (Implemented in Notebook 09, Productionized in API)

```
User Query
    │
    ▼
┌─────────────────────────────────────────────────┐
│ Stage 1: Dense Retrieval (FAISS)                │
│   SentenceTransformer(all-MiniLM-L6-v2)          │
│   → faiss_search(query, top_k=20)               │
│   → cosine similarity scores                    │
└──────────────────┬──────────────────────────────┘
                   │
┌─────────────────────────────────────────────────┐
│ Stage 2: Sparse Retrieval (BM25)                │
│   BM25Okapi (230,088 tokenized docs)            │
│   → bm25_search(query, top_k=20)                │
│   → TF-IDF scores                               │
└──────────────────┬──────────────────────────────┘
                   │
┌─────────────────────────────────────────────────┐
│ Stage 3: RRF Fusion                             │
│   reciprocal_rank_fusion([bm25_df, faiss_df])   │
│   → rrf_score = Σ(1/(60 + rank))                │
│   → top 10 hybrid candidates                    │
└──────────────────┬──────────────────────────────┘
                   │
┌─────────────────────────────────────────────────┐
│ Stage 4: CrossEncoder Reranking                 │
│   ms-marco-MiniLM-L-6-v2                        │
│   → rerank_results(query, hybrid_df, top_k=5)   │
│   → query-document relevance scores             │
└──────────────────┬──────────────────────────────┘
                   │
┌─────────────────────────────────────────────────┐
│ Stage 5: Context Construction                   │
│   build_context(reranked_df)                    │
│   → structured [Document N] chunks              │
│   → duplicate detection & removal               │
│   → token limit validation (≤ 4096)             │
│   → empty context handling                      │
└──────────────────┬──────────────────────────────┘
                   │
┌─────────────────────────────────────────────────┐
│ Stage 6: Groq Generation                        │
│   llama-3.3-70b-versatile                       │
│   → System prompt (IT Service Desk assistant)   │
│   → Context injection (retrieved docs)          │
│   → User question                               │
│   → Temperature 0.1 (deterministic)             │
│   → Max 1024 tokens                             │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
           Final Response
```

### API-Exposed Endpoints (6 endpoints in `app/api/unified_routes.py`)

| Endpoint | Method | Description | Status |
|----------|--------|-------------|--------|
| `/` | GET | Root health message | ✅ |
| `/health` | GET | Component health (FAISS, CrossEncoder, Groq) | ✅ |
| `/retrieve` | POST | Hybrid search (FAISS + BM25 + RRF) | ✅ |
| `/rerank` | POST | Retrieve + CrossEncoder rerank | ✅ |
| `/rag` | POST | Full RAG pipeline (retrieve → rerank → generate) | ✅ |
| `/triage` | POST | XGBoost prediction + escalation risk | ✅ |
| `/copilot` | POST | Combined triage + RAG (uses avg features) | ✅ |

### Retrieval Correctness Rules (Enforced)

| Rule | Status |
|------|--------|
| CrossEncoder reranks AFTER RRF fusion | ✅ Enforced |
| Groq only receives reranked contexts | ✅ Enforced |
| Context deduplication | ✅ Duplicate detection |
| Empty context handling | ✅ Graceful fallback |
| Hallucination minimization | ✅ "Insufficient context" gate |
| Token limit enforcement | ✅ 4096 token limit |

---

## [LATENCY BENCHMARKS]

### Retrieval + RAG Pipeline (09_rag_generation_pipeline, 10 queries)

| Stage | Avg | Min | Max |
|-------|-----|-----|-----|
| Retrieval (FAISS + BM25 + RRF) | 358 ms | 292 ms | 483 ms |
| CrossEncoder Reranking | 370 ms | 164 ms | 986 ms |
| Groq Generation | 1,091 ms | 759 ms | 1,494 ms |
| **Total Pipeline** | **1,821 ms** | **1,331 ms** | **2,543 ms** |
| Gen/Total Ratio | 59.9% | — | — |

### Multi-Query Validation (10 queries)
- Success rate: **10/10** (all returned valid responses)
- Avg context tokens: **198**
- Avg completion tokens: **229**

---

## [GOLD_ML_PIPELINE]

### Architecture

```
gold_ticket_similarity.parquet  (29 cols, 230,114 rows)
    │
    ▼  [Notebook 02: cleaning → 26 short rows removed, 14 cols selected]
    │
retrieval_dataset_clean.parquet  (14 cols, 230,088 rows)
    │
    ├──→ [Notebook 04: Feature Engineering] → feature_engineered_dataset.parquet (21 cols)
    │
    ├──→ [Notebook 05: Retrieval Prep] → retrieval_ready_dataset.parquet + bm25_corpus.pkl
    │
    └──→ [Notebook 11: Gold ML Dataset Builder] → gold_ml_dataset.parquet (consolidated)
                                                    gold_feature_dictionary.json
                                                    gold_quality_report.txt

gold_asset_failure_risk.parquet  (26 cols, 261 rows — UNUSED)
gold_user_activity_anomalies.parquet  (25 cols, 777 rows — UNUSED)
```

### Data Quality Findings

| Dataset | Rows | Null Issues | Label Quality |
|---------|------|-------------|---------------|
| feature_engineered_dataset.parquet | 230,088 | priority/urgency/impact: 99.3% null | Real labels but sparse |
| gold_sla_prediction_features.parquet | 230,114 | urgency/impact: 99.3% null | `was_sla_breached` (0.4% positive) ✅; `is_escalated` (all zeros) ❌ |
| gold_asset_failure_risk.parquet | 261 | anomaly_score, is_anomaly: 100% null | `rule_based_risk_score` ✅ |
| gold_user_activity_anomalies.parquet | 777 | is_anomaly_if/lof: 100% null | `is_suspicious_user` (1.3% pos) ✅ |

---

## [FEATURE_REGISTRY]

### Feature-Engineered Dataset (21 columns)

| Feature | Derivation | Type | Leakage | Consumer |
|---------|-----------|------|---------|----------|
| document_id | `'doc_' + index` | string | None | Notebook 07-09 |
| ticket_pk | From gold_ticket_similarity | string (ID) | None | All notebooks |
| retrieval_text_clean | Cleaned text corpus | string | None | Notebook 07-09, 10 |
| metadata_json | JSON of metadata cols | string | None | Notebook 07-09 |
| source_system_encoded | LabelEncoder(source_system) | int | None | Notebook 10 |
| similarity_method_encoded | LabelEncoder(similarity_method) | int | None | Notebook 10 |
| priority_encoded | Original encoded priority (2-5) | float | N/A (target) | Notebook 10 |
| urgency_encoded | Original encoded urgency (2-5) | float | N/A (target) | Notebook 10 |
| impact_encoded | Original encoded impact (3-5) | float | N/A (target) | Notebook 10 |
| text_word_count | len(text.split()) | int | None | Notebook 10 |
| text_char_count | len(text) | int | None | None |
| avg_word_length | mean(len(w) for w in text) | float | None | Notebook 10 |
| unique_word_ratio | unique_words / total_words | float | None | Notebook 10 |
| uppercase_ratio | uppercase_chars / total_chars | float | None | Notebook 10 |
| digit_ratio | digit_chars / total_chars | float | None | Notebook 10 |
| special_char_ratio | special_chars / total_chars | float | None | Notebook 10 |
| repetition_ratio | — | float | None | None |
| text_complexity_score | 0.4*avg_wl + 0.4*uniq_ratio + 0.2*wc/100 | float | None ✅ | Notebook 10 |
| retrieval_quality_score | mean(corpus_quality, confidence, uniq_ratio) | float | None ✅ | Notebook 10 |
| corpus_quality_score | From gold_ticket_similarity | float | None ✅ | Notebook 10 |
| similarity_confidence | From gold_ticket_similarity | float | None ✅ | Notebook 10 |

### Gold SLA Features (7 features merged by Notebook 11)

| Feature | Derivation | Type | Leakage |
|---------|-----------|------|---------|
| was_sla_breached | From gold_sla_prediction_features | int (0/1) | N/A (target) |
| priority_score | From gold_sla (2-5) | int | None |
| ticket_age_hours | (closed_at - created_at) | float | None |
| resolution_time_hours | From gold_sla | float | None |
| followup_count | From gold_sla | int | None |
| issue_complexity_score | From gold_sla (heuristic) | float | Low |
| customer_tenure_months | From gold_sla | float | None |
| previous_tickets | From gold_sla | int | None |

---

## [MODEL PERFORMANCE]

### XGBoost Multi-Class (382 test samples per target)

| Target | Classes | Accuracy | Macro F1 | Weighted F1 | Recall Macro | Train Time |
|--------|---------|----------|----------|-------------|--------------|------------|
| priority_encoded | 4 (2-5) | 0.9424 | 0.6079 | 0.9386 | 0.5884 | 0.87s |
| urgency_encoded | 4 (2-5) | 0.9398 | 0.6031 | 0.9349 | 0.5940 | 1.12s |
| impact_encoded | 3 (3-5) | 0.9712 | 0.7712 | 0.9676 | 0.7235 | 0.74s |

### Top-3 Predictive Features

| Feature | priority | urgency | impact | Mean |
|---------|----------|---------|--------|------|
| retrieval_quality_score | 0.2453 | 0.1583 | 0.1998 | 0.2011 |
| avg_word_length | 0.2238 | 0.2630 | 0.1631 | 0.2166 |
| text_complexity_score | 0.1790 | 0.2090 | 0.1646 | 0.1842 |

### Escalation Risk Scoring (weighted composite)

| Scenario | Priority | Urgency | Impact | Risk Score | Escalate? |
|----------|----------|---------|--------|------------|-----------|
| Critical | 5 | 5 | 5 | 1.0000 | YES |
| High | 4 | 4 | 4 | 0.6333 | YES |
| Medium | 3 | 3 | 3 | 0.2667 | no |
| Low | 2 | 2 | 3 | 0.0000 | no |

---

## [NOTEBOOK ARCHITECTURE]

| # | Notebook | Description |
|---|----------|-------------|
| 01 | `01_data_understanding.ipynb` | Data understanding & profiling |
| 02 | `02_data_cleaning.ipynb` | Cleaning & preprocessing |
| 03 | `03_eda_visualization.ipynb` | EDA & visual analysis |
| 04 | `04_feature_engineering.ipynb` | Feature engineering |
| 05 | `05_retrieval_preparation.ipynb` | Retrieval data prep |
| 06 | `06_embedding_pipeline.ipynb` | Embedding + FAISS + BM25 creation |
| 07 | `07_hybrid_retrieval.ipynb` | FAISS + BM25 + RRF hybrid retrieval |
| 08 | `08_reranking_pipeline.ipynb` | CrossEncoder reranking + benchmark |
| 09 | `09_rag_generation_pipeline.ipynb` | Full Hybrid RAG with Groq |
| 10 | `10_triage_classification_pipeline.ipynb` | XGBoost + escalation risk |
| 11 | `11_gold_ml_dataset_builder.ipynb` | Gold ML consolidation |

### V2 Notebooks (in `notebooks/V2/`)

| # | Notebook | Export |
|--|----------|--------|
| 01 | `01_data_understanding.ipynb` | `evaluation_v2/data_understanding_report_v2.csv` |
| 02 | `02_data_cleaning.ipynb` | `parquet_exports_v2/retrieval_clean_ready_v2.parquet`, `evaluation_v2/retrieval_ready_v2_sample.csv` |
| 03 | `03_eda_visualization.ipynb` | `evaluation_v2/eda_summary_v2.csv` |
| 04 | `04_feature_engineering.ipynb` | `parquet_exports_v2/feature_engineered_v2.parquet`, `evaluation_v2/feature_dataset_sample_v2.csv` |
| 05 | `05_retrieval_preparation.ipynb` | `parquet_exports_v2/retrieval_ready_dataset_v2.parquet`, `parquet_exports_v2/bm25_corpus_v2.pkl` |
| 06 | `06_embedding_pipeline.ipynb` | `parquet_exports_v2/embedding_metadata.parquet`, `parquet_exports_v2/embeddings.npy`, `parquet_exports_v2/incident_resolution.index` |
| 07 | `07_hybrid_retrieval.ipynb` | `evaluation_v2/hybrid_retrieval_results_v2.csv` |
| 08 | `08_reranking_pipeline.ipynb` | `evaluation_v2/reranking_results_v2.csv`, `evaluation_v2/benchmarks/reranking_latency_v2.csv`, `parquet_exports_v2/solution_lookup_v2.parquet` |

V2 notebooks adapt V1 logic to the V2 dataset (`gold_ticket_similarity_v2.parquet`, 47 cols) with paired `problem_text` + `solution_text` fields.

---

## [APP ARCHITECTURE]

### Actual File Structure

```
backend/
├── main.py                         → Hello world stub (unused)
├── app/
│   ├── main.py                     → FastAPI app entry (lifespan, CORS, router)
│   ├── core/
│   │   ├── config.py               → Settings from .env + path resolution
│   │   ├── logging.py              → Structured logging setup
│   │   └── security.py             → EMPTY (JWT auth not implemented)
│   ├── app_v2/
│   │   ├── config.py               ✅ Settings class from .env via pydantic-settings — 26 vars (Groq LLM, SQLite DB, JWT, embedding, retrieval), 6 validators
│   │   ├── core/
│   │   │   ├── security.py         ✅ JWT (create/decode), bcrypt hash, oauth2_scheme
│   │   │   ├── lifespan.py         ✅ AppState + startup (init_db → model → Qdrant+VectorStore → BM25Tokenizer) + shutdown
│   │   │   └── dependencies.py     ✅ Depends() bridge: get_db, get_qdrant_client, get_vector_store, get_embedding_model, get_bm25_tokenizer, get_current_user (async DB-backed)
│   │   ├── models/
│   │   │   ├── user.py             ✅ User(BaseModel) — username, email, hashed_password
│   │   │   ├── auth.py             ⏳ empty
│   │   │   └── search.py           ⏳ empty
│   │   ├── db/
│   │   │   ├── database.py         ✅ Async SQLAlchemy engine (aiosqlite), init_db(), get_db() generator
│   │   │   ├── user_model.py       ✅ UserDB SQLAlchemy table (id, username, email, hashed_password, is_active, created_at, role)
│   │   │   ├── user_repository.py  ✅ Async CRUD: get/create/exists, bcrypt-hash on insert, 400 on duplicate
│   │   │   └── __init__.py         ✅ empty
│   │   ├── services/               ⏳ not wired
│   │   ├── routers/                ⏳ not wired
│   │   ├── middleware/             ⏳ not wired
│   │   ├── vector_store/           ⏳ not wired
│   │   ├── bm25_tokenizer/         ⏳ placeholder
│   │   └── main.py                 ⏳ not wired
│   ├── api/
│   │   ├── unified_routes.py       → 6 endpoints (health/retrieve/rerank/rag/triage/copilot)
│   │   ├── triage_routes.py        → Re-exports from unified_routes
│   │   └── recommendation_routes.py → Stub (not implemented)
│   ├── shared/schemas/
│   │   └── models.py               → 10 Pydantic models
│   ├── retrieval/
│   │   ├── faiss/faiss_retriever.py   → FAISS search (lazy load)
│   │   ├── bm25/bm25_retriever.py     → BM25 search (lazy load)
│   │   └── hybrid/hybrid_retriever.py → RRF fusion
│   ├── reranking/cross_encoder/
│   │   └── reranker.py             → CrossEncoder reranking
│   ├── rag_pipeline/
│   │   ├── context/context_builder.py → Context assembly
│   │   ├── prompts/system_prompt.py   → IT Service Desk prompt
│   │   ├── generation/generator.py     → Groq client
│   │   └── retrieval_pipeline.py       → Orchestrator
│   ├── triage/inference/
│   │   └── triage_inference.py     → XGBoost prediction + escalation risk
│   └── vector_store/
│       └── chroma_store.py         → EMPTY (not implemented)
├── docker/
│   ├── backend.Dockerfile          → EMPTY
│   └── docker-compose.yml          → EMPTY
├── models/                         → 3 XGBoost JSON models (~2.7 MB)
├── parquet_exports/                → FAISS index, embeddings, metadata, BM25 corpus, datasets
├── parquet_exports_v2/             → V2 datasets
├── evaluation/                     → Benchmark CSVs and reports
├── notebooks/V1/                   → 11 original notebooks
├── notebooks/V2/                   → 4 adapted V2 notebooks
└── tests/
    └── test_api.py                 → 8 tests (root, health, retrieve, rerank, triage, rag, copilot)
```

### API Endpoints (7 total)

| Path | Method | Auth | Description |
|------|--------|------|-------------|
| `/` | GET | ❌ None | Root message |
| `/health` | GET | ❌ None | Component health check |
| `/retrieve` | POST | ❌ None | Hybrid search |
| `/rerank` | POST | ❌ None | Retrieve + rerank |
| `/rag` | POST | ❌ None | Full RAG pipeline |
| `/triage` | POST | ❌ None | XGBoost triage prediction |
| `/copilot` | POST | ❌ None | Triage + RAG combined |

**No authentication is currently implemented.** (security.py is empty)

### Tests

- **8 tests** in `tests/test_api.py` (not 23 as previously claimed)
- Coverage: root, health, retrieve, empty query validation, rerank, triage, rag, copilot
- No auth tests (no auth to test)

---

## [CRITICAL GAPS & ISSUES]

| # | Gap | Location | Severity |
|---|-----|----------|----------|
| 1 | **app_v2 auth done; app/ (V1) still has empty security.py** | `app_v2/core/security.py` has JWT+bcrypt+Depends; `app/core/security.py` is still empty | 🟡 MEDIUM |
| 2 | **No auth/dashboard API routes** | `auth_routes.py`, `dashboard_routes.py` don't exist | 🔴 HIGH |
| 3 | **No frontend-backend integration** | Frontend uses mock data; no API client, no login UI | 🔴 HIGH |
| 4 | **RAGAS evaluation not set up** | `evaluation/ragas/` empty | 🟡 MEDIUM |
| 5 | **Embedding model mismatch** | Notebook 06 uses `paraphrase-multilingual-MiniLM-L12-v2`; query uses `all-MiniLM-L6-v2` (both 384-dim) | 🟡 MEDIUM |
| 6 | **Training data sparsity** | Only 1,527 / 230,088 rows (0.7%) have labels | 🟡 MEDIUM |
| 7 | **Gold: `is_escalated` all zeros** | `gold_sla_prediction_features.parquet` | 🟡 MEDIUM |
| 8 | **Gold: Anomaly scores never computed** | `gold_asset_failure_risk`, `gold_user_activity_anomalies` | 🟡 MEDIUM |
| 9 | **Docker files empty** | `docker/backend.Dockerfile`, `docker/docker-compose.yml` | 🟡 MEDIUM |
| 10 | **README.md empty** | `backend/README.md` | ⚪ LOW |
| 11 | **Chroma store is empty stub** | `app/vector_store/chroma_store.py` | ⚪ LOW |
| 12 | **recommendation_routes.py is stub** | Not implemented | ⚪ LOW |
| 13 | **No GPU utilization** | torch reports CUDA: False | ⚪ LOW |
| 14 | **app_v2/ largely unwired** | `services/`, `routers/`, `middleware/`, `vector_store/`, `main.py` pending; `core/`, `models/user.py`, `db/` done | 🔴 HIGH |

---

## [EXPORTS & ARTIFACTS]

### Parquet Exports (`parquet_exports/`)

| Artifact | Size | Description |
|----------|------|-------------|
| `ticket_similarity.index` | 338 MB | 230,088 × 384 cosine index |
| `embeddings.npy` | 338 MB | Raw float32 embeddings |
| `embedding_metadata.parquet` | 26 MB | 230,088 rows, 9 cols |
| `bm25_corpus.pkl` | 50 MB | Tokenized documents |
| `gold_ml_dataset.parquet` | 28.6 MB | Consolidated Gold ML (34 cols) |
| `gold_feature_dictionary.json` | 5.2 KB | Feature provenance |

### V2 Parquet Exports (`parquet_exports_v2/`)

| Artifact | Description |
|----------|-------------|
| `gold_ticket_similarity_v2.parquet` | Source V2 dataset (47 cols, 108,536 rows) |
| `retrieval_clean_ready_v2.parquet` | Cleaned V2 retrieval dataset (24+ cols) |
| `feature_engineered_v2.parquet` | Feature-engineered V2 dataset (30 cols) |
| `retrieval_ready_dataset_v2.parquet` | Chunked retrieval dataset (109,875 chunks, 11 cols) |
| `bm25_corpus_v2.pkl` | BM25-tokenized corpus (109,875 docs) |
| `embedding_metadata.parquet` | Embedding metadata (109,875 rows, 7 cols) |
| `embeddings.npy` | Raw float32 embeddings (109,875 × 384) |
| `incident_resolution.index` | FAISS IndexFlatIP (109,875 × 384) |
| `solution_lookup_v2.parquet` | rag_id → problem_text + solution_text lookup (108,421 rows) |

### Model Registry (`models/`)

| Model | Size | Classes | Acc | F1-Macro |
|-------|------|---------|-----|----------|
| `xgb_priority_encoded.json` | 976 KB | 4 (2-5) | 0.9424 | 0.6079 |
| `xgb_urgency_encoded.json` | 1.0 MB | 4 (2-5) | 0.9398 | 0.6031 |
| `xgb_impact_encoded.json` | 697 KB | 3 (3-5) | 0.9712 | 0.7712 |

---

## [KNOWN LIMITATIONS]

- **Data sparsity**: Only 0.7% of rows have priority/urgency/impact labels
- **Class imbalance**: Minority classes (2,4,5) have <200 samples each
- **Macro F1 gap**: 0.60 vs accuracy 0.94 — model biased toward majority class (medium)
- **Features**: All 8 triage features are text-statistics derived; no semantic/embedding features
- **No target leakage**: Verified — all derived features from text stats only
- **V2 triage not implemented**: Triage models use V1 features (text_word_count, corpus_quality_score, etc.) — NOT compatible with V2 column schema
- **V1 API still no authentication**: `app/` (V1) endpoints are publicly accessible; `app_v2/` has JWT auth built and wired

---

## [FRONTEND STATUS]

**Project**: `BI-Foundation-main/` (Next.js 15.3.4, React 19, Tailwind v4)

**Current State**: Phase 1 — Pure UI with mock data ✅

| Feature | Status | Notes |
|---------|--------|-------|
| Dashboard with 8 widgets | ✅ | All using mock data from `data.ts` |
| Triage Center with 11 widgets | ✅ | All using mock data |
| Sidebar with 6 routes | ✅ | 2 routes active (/ and /triage-center) |
| Dark theme CSS | ✅ | `@variant dark` ready, no toggle |
| API integration | ❌ | No API client, no env vars, no auth |
| Login UI | ❌ | Not implemented |
| Real-time data | ❌ | Not implemented |
| Tests | ❌ | No test framework configured |
| Responsive design | ❌ | 12-col grid is fixed-width |
| Deploy config | ❌ | No CI/CD, no Docker |

**Orphaned components**: `Grid.tsx`, `RecentTransactions.tsx` (no longer imported)

See `BI-Foundation-main/PROJECT_MAP.md` for full frontend documentation.

---

## [EXECUTION LOG]

| Date | Action | Status |
|------|--------|--------|
| 2026-05-26 | Initial repository analysis | ✅ |
| 2026-05-26 | PROJECT_MAP.md created | ✅ |
| 2026-05-26 | Hybrid retrieval validated | ✅ |
| 2026-05-26 | Notebook 08 productionized | ✅ |
| 2026-05-26 | Notebook 09 productionized (RAG) | ✅ |
| 2026-05-26 | Notebook 10 productionized (triage) | ✅ |
| 2026-05-26 | Models trained + exported | ✅ |
| 2026-05-26 | Gold ML analysis + Notebook 11 | ✅ |
| 2026-05-30 | Backend API (core + routes + services) | ✅ |
| 2026-05-30 | 8 API tests created | ✅ |
| 2026-06-06 | V2 notebooks adapted (01-04) | ✅ |
| 2026-06-06 | PROJECT_MAP.md corrected to match actual code | ✅ |
| 2026-06-06 | V2 notebooks 05-08 completed | ✅ |
| 2026-06-06 | app_v2/config.py — Settings class with 22 vars, .env wired, 6 validators | ✅ |
| 2026-06-06 | app_v2/core/security.py — JWT + bcrypt + get_current_user | ✅ |
| 2026-06-06 | app_v2/core/lifespan.py — AppState + startup/shutdown | ✅ |
| 2026-06-06 | app_v2/core/dependencies.py — Depends() bridge for all routes | ✅ |
| 2026-06-06 | app_v2/models/user.py + app_v2/db/user_repository.py (in-memory) | ✅ |
| 2026-06-09 | app_v2/config.py: replace LLM vars with Groq vars + DATABASE_URL | ✅ |
| 2026-06-09 | app_v2/db/database.py (async SQLAlchemy + aiosqlite), user_model.py | ✅ |
| 2026-06-09 | app_v2/db/user_repository.py rewritten async with DB session | ✅ |
| 2026-06-09 | app_v2/core/lifespan.py: init_db as startup step 0 | ✅ |
| 2026-06-09 | app_v2/core/dependencies.py: wire get_db, async get_current_user | ✅ |
| 2026-06-09 | app_v2/core/security.py: removed old get_current_user (moved to dependencies) | ✅ |
