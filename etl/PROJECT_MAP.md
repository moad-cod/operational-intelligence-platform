# PROJECT MAP — ETL Pipeline

> **Project**: pfe-bachelor/etl — ELT pipeline for IT service management analytics
> **Branch**: `ai/ticket-intelligence-platform`
> **Last Audit**: 2026-05-24
> **Status**: Pre-production — dbt layer complete, ML/RAG layer experimental

---

## 1. PROJECT OVERVIEW

### Mission
Build a centralized data warehouse (`it_data_warehouse`) unifying GLPI ITSM (2013–2015), OCS Inventory (2013–2015), and Kaggle external datasets (CVEs, Windows events, SMART hard drive metrics, laptop pricing, customer support tickets). Transform raw data through dbt (Bronze → Silver → Gold), then serve ML-ready feature vectors for SLA breach prediction, asset anomaly detection, user behavior analysis, and hybrid ticket similarity search.

### Architecture Summary
```
Source Systems / Kaggle CSVs
    │
    ▼
Bronze Layer (22 tables) ← Airflow DAGs + Python ingestion
    │
    ▼
Staging Layer (22 dbt views) ← Per-source cleaning, normalization
    │
    ▼
Silver Layer (5 dbt views) ← Cross-domain integration, feature engineering
    │
    ▼
Gold Layer (4 dbt tables) ← ML-ready serving, one-row-per-entity
    │
    ▼
ML/RAG Pipelines (Notebooks only) ← XGBoost, FAISS, BM25, Groq
```

### Real Maturity Assessment

| Subsystem | Status | Classification |
|-----------|--------|---------------|
| Docker Infrastructure | Working | Production Ready |
| Bronze Ingestion (8 DAGs) | Working | Production Ready |
| Staging dbt (22 models) | Working | Production Ready (fix ~60 test failures) |
| Silver dbt (5 models) | Working | Production Ready |
| Gold dbt (4 models) | Working | Production Ready |
| Gold → Parquet export | Working | Experimental |
| ML Training (Python scripts) | **NOT IMPLEMENTED** | Missing |
| RAG Pipeline (source code) | **NOT IMPLEMENTED** | Missing — notebooks only |
| FAISS Indexing | Notebook-only | Experimental |
| BM25 + RRF | Notebook-only | Experimental |
| Cross-Encoder Reranking | Notebook-only | Experimental |
| Groq Generation | Notebook-only | Experimental |
| RAGAS Evaluation | Notebook-only | Experimental |
| API Service (FastAPI) | **NOT IMPLEMENTED** | Missing |
| CI/CD | **NOT IMPLEMENTED** | Missing |
| Production Monitoring | **NOT IMPLEMENTED** | Missing |

---

## 2. TECH_STACK

### Python Stack

| Category | Package | Version | Notes |
|----------|---------|---------|-------|
| **Language** | Python | 3.12.3 | Host; Airflow uses 3.10 in Docker |
| **Package Manager** | uv | 0.11.7 | `pyproject.toml` + `uv.lock` |
| **Data Processing** | pandas | 2.2.2 | |
| | numpy | 1.26.4 | |
| | pyarrow | 16.1.0 | Parquet export |
| **Database** | SQLAlchemy | 2.0.30 | |
| | PyMySQL | 1.2.0 | MySQL connector |
| **dbt** | dbt-core | 1.7.19 | |
| | dbt-mysql | 1.7.0 | MySQL adapter |

### ML Stack

| Category | Package | Version | Status |
|----------|---------|---------|--------|
| **Boosting** | xgboost | 2.0.3 | Installed, no production script |
| | lightgbm | 4.3.0 | Installed, no production script |
| **Anomaly** | scikit-learn | 1.5.0 | Installed, no production script |
| **Embeddings** | sentence-transformers | 2.7.0 | ⚠️ Notebook uses `>=3.0` — version mismatch |
| | transformers | 4.57.6 | |
| | torch | 2.12.0 | CPU-only (no CUDA) |
| **Retrieval** | faiss-cpu | 1.8.0 | Notebook only |
| | rank-bm25 | 0.2.2 | Notebook only |
| **LLM** | groq | 0.9.0 | Notebook only |
| **Evaluation** | ragas | 0.1.9 | ⚠️ Notebook uses `>=0.2.6` — version mismatch |
| **RAG Framework** | llama-index | 0.10.40 | Installed but unused in any pipeline |
| | langchain | 0.3.30 | Dependency of ragas |

### Orchestration Stack

| Category | Technology | Version | Notes |
|----------|-----------|---------|-------|
| **Orchestration** | Apache Airflow | 2.7.1 | LocalExecutor; 8 DAGs (7 manual, 1 `@daily`) |
| **Airflow Metadata** | PostgreSQL | 15 | Docker container |
| **Airflow Provider** | apache-airflow-providers-mysql | latest | |

### Infrastructure Stack

| Category | Technology | Version | Notes |
|----------|-----------|---------|-------|
| **Containerization** | Docker Compose | — | 4 services |
| **Platform DB** | MySQL | 8.0 | Source: `platform_db` (3307) |
| **Warehouse DB** | MySQL | 8.0 | Target: `warehouse_db` (3308) |
| **PostgreSQL** | PostgreSQL | 15 | Airflow metadata |

### Compatibility Warnings

| Issue | Detail | Risk |
|-------|--------|------|
| **sentence-transformers 2.7 vs notebook 3.0** | Notebook v4 requires `>=3.0`, .venv has 2.7.0 | API breaking changes between 2.x and 3.x |
| **ragas 0.1.9 vs notebook 0.2.6** | Notebook v4 requires `>=0.2.6`, .venv has 0.1.9 | API breaking changes; evaluation will fail |
| **No CUDA** | `nvidia-smi` not found | CPU-only training; large embedding jobs will be slow |
| **dbt-mysql 1.7.0** | Uses mysqlconnector under the hood | Known composite PK issues with MySQL views |
| **PyTorch 2.12 CPU-only** | No GPU acceleration | embedding batch_size limited to ~32 locally |

---

## 3. SYSTEM_FLOW

### End-to-End Data Flow

```
Raw Data (GLPI/OCS/CSVs)
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│ BRONZE LAYER (Airflow DAGs → Python → MySQL warehouse_db)   │
│                                                             │
│  GLPI (3 yearly DBs → 10 tables)     OCS (3 yearly DBs → 7)│
│  ┌──────────────────────────────┐   ┌─────────────────────┐ │
│  │ bronze_glpi_tickets          │   │ bronze_ocs_hardware  │ │
│  │ bronze_glpi_users            │   │ bronze_ocs_bios      │ │
│  │ bronze_glpi_computers        │   │ bronze_ocs_drives    │ │
│  │ bronze_glpi_logs             │   │ bronze_ocs_software  │ │
│  │ bronze_glpi_ticketfollowups  │   │ bronze_ocs_memories  │ │
│  │ bronze_glpi_infocoms         │   │ bronze_ocs_networks  │ │
│  │ bronze_glpi_deviceprocessors │   │ bronze_ocs_storages  │ │
│  │ bronze_glpi_devicememories   │   └─────────────────────┘ │
│  │ bronze_glpi_devicegraphiccards│                          │
│  │ bronze_glpi_itilcategories   │   Kaggle CSVs (5 tables)  │
│  └──────────────────────────────┘   ┌─────────────────────┐ │
│                                     │ raw_cve_data         │ │
│                                     │ raw_windows_eventlog │ │
│                                     │ raw_harddrive_data   │ │
│                                     │ raw_laptop_price_data│ │
│                                     │ customer_support_*   │ │
│                                     │ dataset_tickets_*    │ │
│                                     └─────────────────────┘ │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ STAGING LAYER (dbt views — 22 models)                      │
│                                                             │
│  GLPI (10): tickets, users, computers, logs, followups,     │
│            infocoms, deviceprocessors, devicememories,       │
│            devicegraphiccards, itilcategories                │
│  OCS (7): hardware, bios, drives, software, memories,        │
│           networks, storages                                 │
│  Kaggle (5): cve, harddrive, laptop_price, windows_eventlog, │
│              tickets (unions 2 CSV sources)                  │
│                                                             │
│  Transformations: composite PKs, MD5 surrogate keys,        │
│  date cleaning, type casting, categorization, scoring       │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ SILVER LAYER (dbt views — 5 models)                        │
│                                                             │
│  silver_tickets ← stg_glpi_tickets + stg_kaggle_tickets     │
│  silver_assets ← 8 OCS/GLPI staging models                  │
│  silver_security_events ← CVE + Windows + GLPI tickets      │
│  silver_triage_features ← silver_tickets (derived features) │
│  silver_user_activity ← users + logs + followups + OCS      │
│                                                             │
│  Transformations: ROW_NUMBER dedup, enum standardization,   │
│  risk scoring (0-10), priority encoding (1-5)               │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ GOLD LAYER (dbt tables — 4 models)                         │
│                                                             │
│  gold_sla_prediction_features    → XGBoost/LightGBM         │
│  gold_ticket_similarity          → FAISS + BM25 + CrossEnc  │
│  gold_asset_failure_risk         → Isolation Forest         │
│  gold_user_activity_anomalies    → Isolation Forest + LOF   │
│                                                             │
│  Note: ML output columns are NULL — populated by Python     │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ ML / RAG PIPELINES (Notebook-only — no production scripts)  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  rag/testing-Kaggle-notebooks/                      │   │
│  │  ├── rag-system_v1.ipynb  (initial prototype)       │   │
│  │  ├── rag-system_v2.ipynb  (FAISS + BM25)            │   │
│  │  ├── rag_system_v3.ipynb  (RRF + Cross-encoder)     │   │
│  │  └── rag_system_v4.ipynb  (Groq + RAGAS eval)      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  pipeline/analyses/export_gold_to_parquet.py                 │
│    → exports gold tables to parquet_exports/*.parquet       │
│    ⚠️ Uses wrong DB name: it_data_warehouse_gold            │
│                                                             │
│  Missing: prod scripts for ML training, FAISS indexing,     │
│  RAG serving, API layer                                     │
└─────────────────────────────────────────────────────────────┘
```

### Data Lineage (Bronze → Gold)

```
bronze_glpi_tickets ──→ stg_glpi_tickets ──┐
bronze_glpi_users ────→ stg_glpi_users ────┤
bronze_glpi_computers → stg_glpi_computers ─┤
bronze_glpi_logs ─────→ stg_glpi_logs ─────┤
bronze_glpi_ticketfollowups → stg_followups ┤
bronze_glpi_infocoms ─→ stg_glpi_infocoms ─┤
bronze_glpi_device* ───→ stg_glpi_device* ─┤
bronze_glpi_itilcategories → stg_itilcats ─┤
                                            │
bronze_ocs_hardware ──→ stg_ocs_hardware ───┤
bronze_ocs_bios ──────→ stg_ocs_bios ──────┤
bronze_ocs_drives ────→ stg_ocs_drives ────┤
bronze_ocs_software ──→ stg_ocs_software ──┤
bronze_ocs_memories ──→ stg_ocs_memories ──┤
bronze_ocs_networks ───→ stg_ocs_networks ─┤
bronze_ocs_storages ───→ stg_ocs_storages ─┤
                                            │
raw_cve_data ──────────→ stg_cve_kaggle ────┤
raw_windows_eventlog ──→ stg_windows_evt ──┤
raw_harddrive_data ────→ stg_harddrive ────┤
raw_laptop_price_data ─→ stg_laptop_price ─┤
customer_support_* ────→ stg_kaggle_tickets ┤
dataset_tickets_* ─────→ stg_kaggle_tickets ┘
                                            │
                    ┌───────────────────────┘
                    ▼
         ┌──────────────────┐
         │ silver_tickets   │──→ silver_triage_features
         │ silver_assets    │
         │ silver_security  │
         │ silver_user_act  │
         └────────┬─────────┘
                  │
          ┌───────┴────────┐
          ▼                ▼
  gold_sla_pred   gold_ticket_sim
  gold_asset_fail gold_user_act_anom
```

---

## 4. ARCHITECTURE

### dbt Architecture

| Layer | Models | Materialization | Dependencies |
|-------|--------|----------------|--------------|
| Staging | 22 | view | Bronze sources (22 tables) |
| Silver | 5 | view | Staging models |
| Gold | 4 | table | Staging models + 1 bronze direct ref |

**Config** (`pipeline/dbt_project.yml`):
- staging: `+materialized: view`
- silver: `+materialized: view`
- gold: `+materialized: table`, `+schema: gold`

### ML Architecture (Planned — Not Implemented in Production)

```
Gold Tables (dbt)
    │
    ├── gold_sla_prediction_features → XGBoost/LightGBM classifier → pred_sla_breach
    ├── gold_ticket_similarity       → sentence-transformers → FAISS index
    │                                  → BM25 → RRF → Cross-encoder reranking
    ├── gold_asset_failure_risk      → Isolation Forest → anomaly scores
    └── gold_user_activity_anomalies → Isolation Forest + LOF → anomaly scores
```

**Reality**: ML columns in gold tables are NULL. No production training scripts exist.

### RAG Architecture (Notebook-only)

```
Kaggle Tickets (text_corpus)       GLPI Tickets (synthetic_text_corpus)
    │                                      │
    ▼                                      ▼
sentence-transformers                 TF-IDF / SentenceTransformer
    │                                      │
    ▼                                      ▼
FAISS Dense Index                    FAISS Dense Index
    │
    ├── BM25 Sparse Index (Kaggle only)
    │
    ▼
Reciprocal Rank Fusion (RRF)
    │
    ▼
Cross-Encoder Re-ranking (cross-encoder/ms-marco-MiniLM-L-6-v2)
    │
    ▼
Groq LLM (llama3-70b-8192)
    │
    ▼
RAGAS Evaluation (faithfulness + answer relevancy)
```

**Reality**: Implemented only in `rag_system_v4.ipynb`. No modularized `src/` files.

---

## 5. GOLD_LAYER

### Model Registry

#### gold_sla_prediction_features
| Property | Value |
|----------|-------|
| **Purpose** | SLA breach binary classification |
| **Sources** | `stg_glpi_tickets`, `stg_glpi_ticketfollowups`, `stg_kaggle_tickets` |
| **Rows** | One per ticket (GLPI + Kaggle union) |
| **Target** | `was_sla_breached` (0/1) |
| **Features** | priority_score, urgency_score, impact_score, ticket_age_hours, resolution_time_hours, waiting_duration, takeintoaccount_delay, followup_count, private_followup_ratio, avg_followup_content_length, issue_complexity_score, customer_tenure_months, previous_tickets, is_escalated |
| **ML Status** | ❌ No model trained — columns defined, ML scripts missing |
| **Limitations** | GLPI rows have NULL complexity/tenure/escalation — Kaggle-only features. `was_sla_breached` is a heuristic, not ground truth. |
| **Downstream** | `pred_sla_breach` table (not implemented) |

#### gold_ticket_similarity
| Property | Value |
|----------|-------|
| **Purpose** | Hybrid similarity: real NLP (Kaggle) + synthetic context (GLPI) |
| **Sources** | `stg_glpi_tickets`, `stg_glpi_ticketfollowups`, `stg_kaggle_tickets`, `bronze_glpi_tickets`, `stg_glpi_computers`, `stg_ocs_hardware`, `stg_ocs_bios`, `stg_ocs_software` |
| **Corpus Quality** | Kaggle: 1.00 (real text). GLPI: 0.30–0.70 (synthetic metadata tokens) |
| **Confidence** | Kaggle: 0.90. GLPI: 0.25–0.65 |
| **ML Status** | ❌ No embeddings/FAISS index built in production. Notebook-only. |
| **Critical Issue** | GLPI `ticket_subject` and `ticket_body` are NULL for ALL rows. No real NLP text. |
| **Downstream** | FAISS index, BM25 index (not implemented) |

#### gold_ticket_similarity_v2
| Property | Value |
|----------|-------|
| **Purpose** | Production RAG Knowledge Base — one row per resolved ticket with cleaned problem_text (embedding source) and solution_text (retrieved answer) |
| **Sources** | `silver_ticket_corpus`, `silver_triage_features` |
| **Rows** | 108,536 (after quality filters: ≥20 chars, resolved/closed only, GLPI excluded) |
| **Distribution** | customer_support: 79,999, multi_lang: 28,537 (GLPI excluded — see "Why GLPI is Excluded") |
| **RAG ID** | `MD5(event_pk)` — unique, deterministic, stable across rebuilds |
| **problem_text** | Kaggle: ticket_subject + ticket_body |
| **solution_text** | customer_support: resolution_notes. multi_lang: answer |
| **Metadata** | category, priority, language, product, queue, software_version, region, tags |
| **Triage** | priority_tier, triage_priority, escalation_risk_level |
| **Ranking** | resolution_time_hours, first_response_time_hours, sla_risk_score |
| **SLA** | is_sla_breached, is_escalated |
| **Customer** | customer_segment, subscription_type, operating_system, browser |
| **Governance** | source_dataset, created_at, resolved_at |
| **Downstream** | SentenceTransformers, Qdrant/FAISS, BM25, Cross-Encoder, Groq generation |
| **Architecture Rule** | Built exclusively on Silver models — no direct staging/bronze refs |
| **Why GLPI is Excluded** | GLPI tickets are operational ITSM records without native ticket_subject or ticket_body. Their problem_text/solution_text are both reconstructed from followup content, lacking the rich, natural-language problem-solution pairs needed for semantic search, embedding, and RAG. Only Kaggle support datasets (customer_support_tickets_200k, dataset_tickets_multi_lang) are retained. |

#### gold_asset_failure_risk
| Property | Value |
|----------|-------|
| **Purpose** | Unsupervised anomaly detection on IT assets |
| **Sources** | 8 staging models (OCS hardware, bios, drives, storages, software, GLPI computers, infocoms, tickets) |
| **Features** | device_age_years, bios_risk_level_encoded, worst_drive_health_encoded, total_drive_gb, drive_count, high_risk_software_count, risk_software_ratio, memory_gb, cpu_cores, incident_count, days_since_last_inventory, rule_based_risk_score |
| **ML Status** | ❌ No Isolation Forest trained. `anomaly_score`, `is_anomaly` are NULL. |
| **Limitations** | No labeled failure events — fully unsupervised. `rule_based_risk_score` is a heuristic baseline. |

#### gold_user_activity_anomalies
| Property | Value |
|----------|-------|
| **Purpose** | Behavioral anomaly detection per user |
| **Sources** | `stg_glpi_users`, `stg_glpi_logs`, `stg_glpi_ticketfollowups`, `stg_ocs_hardware` |
| **Features** | total_activity_count, followup_count, log_action_count, ocs_inventory_count, private_followup_ratio, url_content_ratio, avg_followup_length, write_action_ratio, activity_density, active_data_sources |
| **ML Status** | ❌ No Isolation Forest/LOF trained. `isolation_forest_score`, `lof_score`, `is_anomaly_if`, `is_anomaly_lof` are NULL. |
| **Limitations** | `is_suspicious_user` is a weak heuristic — must NOT be used as ground truth. No login/authentication data exists. |

---

## 6. ML_MODEL_REGISTRY

| Model | Algorithm | Gold Dataset | Training Script | Eval | Status |
|-------|-----------|-------------|----------------|------|--------|
| SLA Breach Prediction | XGBoost/LightGBM | `gold_sla_prediction_features` | ❌ Missing | ❌ Missing | Blocked |
| Ticket Similarity (Kaggle) | sentence-transformers → FAISS | `gold_ticket_similarity` | Notebook-only | Notebook-only | Experimental |
| Ticket Similarity (GLPI) | TF-IDF / SentenceTransformer | `gold_ticket_similarity` | Notebook-only | Notebook-only | Experimental |
| Hybrid Retrieval | RRF + Cross-encoder | FAISS + BM25 indexes | Notebook-only | Notebook-only | Experimental |
| RAG Generation | Groq (llama3-70b-8192) | Retrieved contexts | Notebook-only | Notebook-only | Experimental |
| Asset Failure Risk | Isolation Forest | `gold_asset_failure_risk` | ❌ Missing | ❌ Missing | Blocked |
| User Activity Anomalies | Isolation Forest + LOF | `gold_user_activity_anomalies` | ❌ Missing | ❌ Missing | Blocked |

---

## 7. RETRIEVAL_PIPELINE

### Current State

| Component | Implemented | Location | Status |
|-----------|------------|----------|--------|
| Dense Retrieval (FAISS) | Yes | Notebook Cell 18-20 | Experimental |
| Sparse Retrieval (BM25) | Yes | Notebook Cell 21-22 | Experimental |
| RRF Fusion | Yes | Notebook Cell 25 | Experimental |
| Cross-Encoder Re-ranking | Yes | Notebook Cell 28-29 | Experimental |
| Groq Generation | Yes | Notebook Cell 31-34 | Experimental |
| RAGAS Evaluation | Yes | Notebook Cell 38 | Experimental |
| Production API | No | — | Missing |
| Modular src/ files | No | — | Fabricated in PROJECT_MAP |

### Hybrid Retrieval Design (from notebook v4)

```
Query
  │
  ├──→ FAISS Dense Search (k=100)  → dense_scores
  │
  ├──→ BM25 Sparse Search (k=100)  → sparse_scores
  │
  └──→ RRF Fusion: scores = Σ 1/(k + rank)
       where k=60 (default)
  │
  ▼
Top-K results (k=20)
  │
  ▼
Cross-Encoder Re-ranking (cross-encoder/ms-marco-MiniLM-L-6-v2)
  │
  ▼
Top-K reranked (k=5)
  │
  ▼
Groq Generation (llama3-70b-8192)
  │
  ▼
RAGAS Evaluation (faithfulness + answer_relevancy)
```

### Critical Validation

| Claim | Validation | Verdict |
|-------|-----------|---------|
| GLPI semantic retrieval | GLPI has NULL text — synthetic tokens only | **Synthetic, not semantic** |
| BM25 on synthetic corpora | BM25 on metadata tokens (prio_critical, urg_high...) is keyword matching on artificial strings | **Minimal semantic value** |
| RRF mathematical correctness | `score = Σ 1/(k + rank)` with k=60, applied after dense + sparse independently | ✓ Standard RRF implementation |
| Reranking after fusion | Cross-encoder applied to top 20 hybrid results | ✓ Correct order |
| RAGAS evaluation validity | ragas 0.1.9 used (notebook specifies 0.2.6+); version mismatch | ⚠️ May fail at runtime |

---

## 8. DATA_LIMITATIONS

### Hard Constraints

| Limitation | Source | Impact | Mitigation |
|-----------|--------|--------|-----------|
| **No ticket text for GLPI** | `stg_glpi_tickets` | `ticket_subject`, `ticket_body`, `category` are NULL for ALL GLPI rows | Synthetic context reconstruction only (confidence 0.25–0.65) |
| **Synthetic corpus is NOT language** | `gold_ticket_similarity` | `synthetic_text_corpus` = space-separated metadata tokens | Not suitable for semantic NLP; structured embedding only |
| **Data only 2013–2015** | Source DB dumps | 10+ year old data; temporal drift likely | No newer data available |
| **No login/authentication data** | None in any source | Cannot compute login frequency, session metrics | Cannot detect account compromise |
| **No geolocation** | None exists | Cannot compute geo_variance | IP→geo not implemented |
| **`is_suspicious_user` is heuristic** | `stg_glpi_users` | Not ground truth — weak rules only | Post-hoc validation only |
| **Followup text not extracted** | `stg_glpi_ticketfollowups` | Only metadata (length, privacy, URL presence) | Full text extraction not implemented |
| **Weak anomaly labels** | All gold models | SLA breach, suspicious activity, risk scores are heuristic, not verified | Unsupervised methods only |
| **Kaggle ticket data quality** | 2 CSV datasets | Heterogeneous schemas, NULL-padded union | Documented in schema.yml |

### Synthetic Corpus Token Examples
```
GLPI Ticket → "prio_critical urg_high impact_medium sla_breached
               very_long_resolution multiple_followups
               private_heavy_ticket windows_environment
               low_memory_device critical_bios_risk"
```

---

## 9. ORPHANS_AND_PENDING

### 🔴 Missing Production Systems

| System | Location | Impact | Priority |
|--------|----------|--------|----------|
| Python ML training scripts | `pipeline/ml/` | No trained models. Gold NULL columns never populated. | Critical |
| Modular RAG pipeline | `src/` | RAG exists only in notebooks. No production FAISS/BM25/reranking. | Critical |
| FastAPI serving layer | `api/` | No REST API for dashboard consumption. | High |
| CI/CD pipeline | — | No automated testing, deployment, or validation. | High |
| dbt `profiles.yml` | `~/.dbt/` | Cannot run dbt without manual setup (gitignored). | High |

### 🔴 Test Issues

| Issue | Location | Detail |
|-------|----------|--------|
| **~60 dbt test failures** | `staging/schema.yml` | Tests reference columns not produced by SQL models |
| **41,885 duplicate PKs** | `stg_ocs_software` | MD5 surrogate key collision — not unique |
| **Copy-paste bug** | `tests/staging/ocs/stg_ocs_storages_test.sql` | References `stg_ocs_software` instead of `stg_ocs_storages` |
| **Missing `_test` suffix** | `tests/staging/glpi/stg_glpi_computers.sql` | Breaks naming convention |
| **Silver materialization mismatch** | `dbt_project.yml` | Silver is `view` but documentation says "tables" |

### 🗑️ Orphaned / Unused Files

| File | Reason |
|------|--------|
| `airflow/data/Linux_2k.log` | No ingestion script references it |
| `pipeline/models/staging/README.md` | Contains scratch git notes, not documentation |
| `main.py` | Stub — prints "Hello from pfe-bachelor!", not wired |
| `pipeline/README.md` | Default dbt README, not customized |

### ⚠️ Config/Code Issues

| Issue | Detail | Risk |
|-------|--------|------|
| **Wrong DB name in export script** | `export_gold_to_parquet.py` uses `it_data_warehouse_gold` but dbt uses `it_data_warehouse` | Export will fail with "database not found" |
| **RAG pipeline documented as "Built"** | PROJECT_MAP.md claims `src/config.py` etc. exist | Files do not exist in repo — fabricated documentation |
| **Notebook imports `sentence-transformers>=3.0`** | .venv has 2.7.0 | Installation cell will upgrade and may break |
| **Notebook imports `ragas>=0.2.6`** | .venv has 0.1.9 | Installation cell will upgrade; API changes likely |

### 📋 Pending Work

| Item | Priority | Status |
|------|----------|--------|
| Build ML training scripts (XGBoost, IF, LOF) | Critical | Not started |
| Build production FAISS indexing | Critical | Notebook only |
| Build production BM25 + RRF | Critical | Notebook only |
| Build production cross-encoder reranking | Critical | Notebook only |
| Build Groq generation service | Critical | Notebook only |
| Build RAGAS evaluation pipeline | Critical | Notebook only |
| Build FastAPI serving layer | High | Not started |
| Fix ~60 dbt staging test failures | High | Known |
| Fix `stg_ocs_software` duplicate PKs | High | Known |
| Fix `stg_ocs_storages_test.sql` copy-paste bug | Low | Known |
| Rename `stg_glpi_computers.sql` test | Low | Known |
| Fix export script DB name | High | Known |
| Change silver materialization to `table` | Medium | Planned |
| Move credentials to Airflow connections | Medium | Known |
| Implement `pred_*` prediction tables | Critical | Not started |
| Extract shared ingestion module (Kaggle scripts) | Medium | Known |
| Add sentiment scoring to silver_tickets | Low | Null fields |

---

## 10. TECHNICAL_DEBT

### Critical Debt

| Debt | Location | Impact | Fix |
|------|----------|--------|-----|
| **No production ML scripts** | `pipeline/ml/` (missing) | Gold tables are dead ends — ML columns permanently NULL | Create Python package with training pipeline |
| **RAG pipeline not productionized** | `rag/testing-Kaggle-notebooks/` | ML pipeline is only executable in Kaggle notebooks | Extract to Python modules with CLI entrypoints |
| **Fabricated RAG documentation** | `PROJECT_MAP.md` (uncommitted) | Claims `src/` files exist that don't | Remove fabricated section or implement files |
| **Wrong database name** | `pipeline/analyses/export_gold_to_parquet.py:13` | `it_data_warehouse_gold` doesn't exist | Fix to `it_data_warehouse` |
| **Hardcoded credentials** | All 8 ingestion scripts | MySQL passwords in plain text | Move to Airflow connections / env vars |
| **Duplicate ingestion pattern** | 4 Kaggle scripts | ~80% code duplication | Extract shared module |

### Medium Debt

| Debt | Impact | Notes |
|------|--------|-------|
| **~60 dbt test failures** | Low (staging is views, not enforced) | Schema mismatch between tests and SQL |
| **41,885 duplicate OCS software PKs** | Breaks `unique` test | MD5 collision on combined key |
| **Hostname inconsistency** | `extract_ocs_bronze.py` uses `glpi_ocs_db`, `ingest_ocs_softwares.py` uses `platform_db` | Different Docker DNS resolution |
| **Missing error handling** | Kaggle scripts only check file existence | No retry, alerting, structured logging |
| **pkg_resources deprecation** | .venv uses setuptools<81 | Warning on import |

### Scalability Risks

| Risk | Detail |
|------|--------|
| **MySQL as analytics warehouse** | MySQL is not designed for OLAP workloads. Gold model queries with large aggregations will be slow. |
| **Gold tables materialized as full tables** | No incremental loading — full rebuild every `dbt run`. 200k+ Kaggle tickets will become expensive. |
| **CPU-only ML training** | No GPU. XGBoost/FAISS on large datasets (200k tickets, 579MB harddrive CSV) will be slow. |
| **Notebook-only RAG pipeline** | Cannot be scheduled, monitored, or served. No versioning, no CI, no tests. |

---

## 11. ARCHITECTURE GAP ANALYSIS

### Gap 1: ML Pipeline Missing (Critical)
Gold tables are designed for ML consumption but contain NULL output columns. No training scripts exist outside notebooks. The entire ML layer is a schema contract waiting for implementation.

### Gap 2: RAG Pipeline Unshippable (Critical)
The v4 notebook implements a complete RAG pipeline (FAISS + BM25 + RRF + Cross-encoder + Groq + RAGAS) but it's locked in a Jupyter notebook. No modular code, no CLI, no API, no Docker image.

### Gap 3: Fabricated Documentation (High)
The uncommitted PROJECT_MAP.md additions claim `src/config.py`, `src/embedding/shared_embedder.py` and 13 other source files exist as "Built". They do not exist in the repository. This is a documentation integrity issue.

### Gap 4: Version Mismatches (Medium)
- Notebook requires `sentence-transformers>=3.0` but .venv has 2.7.0
- Notebook requires `ragas>=0.2.6` but .venv has 0.1.9
- Installing notebook deps may upgrade/break existing packages

### Gap 5: No Serving Layer (High)
No API, no dashboard connectivity, no `pred_*` tables. The pipeline ends at gold tables with NULL ML columns.

### Gap 6: No Observability (Medium)
No monitoring, alerting, data quality dashboards, or drift detection. dbt tests exist but ~60 fail.

---

## 12. ML/RAG MATURITY ASSESSMENT

| Dimension | Score (1-5) | Notes |
|-----------|-------------|-------|
| **Data Readiness** | 4/5 | Bronze → Gold dbt pipeline is complete and well-designed |
| **Feature Engineering** | 4/5 | Gold features are well-documented with confidence scores |
| **Model Training** | 1/5 | No production training code |
| **Model Evaluation** | 1/5 | No evaluation harness outside notebooks |
| **Serving Infrastructure** | 0/5 | No API or dashboard integration |
| **Monitoring & Observability** | 0/5 | Nothing implemented |
| **CI/CD** | 0/5 | Nothing implemented |
| **Documentation Integrity** | 2/5 | Fabricated RAG pipeline section undermines trust |

**Overall Maturity**: **Pre-Alpha** — The data platform (dbt) is production-ready, but the ML/RAG layer is experimental notebook-only code with no path to production.

---

## 13. RECOMMENDED MILESTONES

### Milestone 1: Fix Documentation Integrity
```
Goal: Remove fabricated RAG pipeline claims from PROJECT_MAP.md
Validation: PROJECT_MAP.md accurately reflects only what exists in the repo
Deliverable: Cleaned PROJECT_MAP.md with accurate status markers
```

### Milestone 2: Production ML Training Scripts
```
Goal: Train XGBoost (SLA), Isolation Forest (assets), Isolation Forest + LOF (users)
Validation: pred_* tables populated in warehouse, model .pkl artifacts saved
Deliverable: pipeline/ml/train_sla.py, pipeline/ml/train_anomaly_asset.py,
             pipeline/ml/train_anomaly_user.py
```

### Milestone 3: Production RAG Pipeline
```
Goal: Extract notebook v4 into modular Python package under pipeline/rag/
Validation: CLI entrypoints for index build, retrieval, generation, evaluation
Deliverable: pipeline/rag/build_indexes.py, pipeline/rag/retriever.py,
             pipeline/rag/generator.py, pipeline/rag/evaluator.py
```

### Milestone 4: Fix All dbt Test Failures
```
Goal: 0 failing tests on dbt test
Validation: dbt test returns 0 failures
Deliverable: Fixed schema.yml, fixed stg_ocs_software PK, fixed copy-paste bug
```

### Milestone 5: FastAPI Serving Layer
```
Goal: REST API serving predictions, similarity search, and anomaly scores
Validation: curl /predict/sla, curl /search/similar, curl /anomaly/asset return JSON
Deliverable: api/app.py with 3+ endpoints
```

### Milestone 6: Version Alignment & Environment Stability
```
Goal: pyproject.toml versions match notebook requirements or vice versa
Validation: pip install succeeds, notebook runs without version conflicts
Deliverable: Updated pyproject.toml, updated notebook install cells
```
<<<<<<< Updated upstream
=======

---

## 14. RECENT SESSION LOG

### Session 2026-06-02 — dbt Fixes & Export Cleanup

**Accomplished:**
1. Fixed `stg_kaggle_tickets.sql` — `is_escalated` and `is_sla_breached` now handle `'Yes'`/`'No'` values (not just `'true'`/`'1'`)
2. Fixed `stg_glpi_tickets.sql` — status comparisons match string values (`'closed'`, `'solved'`, etc.) not just integers
3. Fixed `silver_tickets.sql` — `ticket_status` mapping for GLPI matches string status values
4. Fixed `export_gold_to_parquet.py` — uses env vars, correct relative paths, no emojis
5. Updated `pyproject.toml` — `sentence-transformers>=3.0.0`, `ragas>=0.2.6` (resolves version mismatches)
6. Cleaned up orphan files: `airflow/data/Linux_2k.log`, `main.py`, `pipeline/README.md`, `pipeline/models/staging/README.md`
7. Built/verified all 22 staging models, 5 silver models (as tables), 2 of 4 gold models
8. All 422 dbt tests pass: 313 staging + 63 silver + 46 gold
9. Export script runs successfully, creates 4 parquet files (41 MB total)
10. Key metrics verified: `gold_sla_prediction_features` = 230,114 rows, `was_sla_breached` (GLPI) = 911, `is_escalated` now has ~50/50 split for customer_support

**Known Limitations:**
- `gold_asset_failure_risk`: built (261 rows, 35K parquet) but query is extremely slow (8-table join + window function)
- `gold_ticket_similarity`: built (23M parquet) but underlying infrastructure join is complex and slow
- These 2 gold models exist as tables from prior runs but their dbt builds are unreliable due to MySQL resource constraints

**Pending (updated from §9):**
- ML training scripts (XGBoost, IF, LOF) — still not started
- Production FAISS/BM25/RRF/cross-encoder — still notebook-only
- FastAPI serving layer — still not started
- ~60 dbt test failures now resolved → reclassify as closed
- `stg_ocs_software` duplicate PKs — still unresolved
- `stg_ocs_storages_test.sql` copy-paste bug — still unresolved
- Export script DB name — now fixed, reclassify as closed
- Silver materialization changed to `table` — now applied, reclassify as closed
- Credential management — still in Airflow connections todo
- Gold `gold_asset_failure_risk` and `gold_ticket_similarity` build performance — known bottleneck

---

## 15. RECENT SESSION LOG

### Session 2026-06-06 — gold_ticket_similarity_v2 Implementation

**New Models:**
1. `silver_followups` — Aggregates GLPI followup content per (ticket_id, source_year) for use as GLPI ticket text corpus. 157 rows.
2. `silver_ticket_corpus` — Prepares problem_text and solution_text from all ticket sources. Joins silver_tickets + stg_kaggle_metadata + stg_glpi_metadata + silver_followups. 230,114 rows.
3. `gold_ticket_similarity_v2` — Production RAG Knowledge Base. References ONLY silver layer models. Applies quality filters (≥20 chars, resolved/closed). 108,766 rows.

**Architecture:**
- Medallion: Silver_ticket_corpus/silver_followups (Silver) → gold_ticket_similarity_v2 (Gold)
- No direct staging references in gold model — pure Silver-layer dependency
- No embedding generation, no similarity computation inside dbt
- rag_id = MD5(event_pk) — deterministic, stable across rebuilds

**Test Results:**
- 10/10 v2 tests PASS (unique rag_id, not_null problem_text/solution_text, accepted_values for source_dataset, is_sla_breached, is_escalated)
- 56/56 total gold tests PASS (original 46 + 10 new)
- No regressions

**Downstream Consumers:**
- SentenceTransformers (embedding generation)
- Qdrant / FAISS (vector storage)
- BM25 + RRF (hybrid search)
- Cross-Encoder reranking
- Groq-based AI ticket recommendation

**Known Limitations:**
- GLPI tickets (230 rows) relied on followup content only — excluded in v2.1 (2026-06-06)
- multi_lang dataset (28,537 rows) has no timestamps (created_at/resolved_at are NULL — quality filter accepts them since ticket_status = 'resolved' is hardcoded)
- communication_channel unavailable in silver_tickets — excluded from v2

### Session 2026-06-06 (Part 2) — GLPI Exclusion from gold_ticket_similarity_v2

**Change:**
- GLPI records are now excluded from `gold_ticket_similarity_v2`
- Filter applied in first CTE (`ticket_base`) before LEFT JOIN to `silver_triage_features`
- Filter column: `source_system != 'GLPI'` (available in `silver_ticket_corpus`)

**Rationale:**
- GLPI tickets have NULL ticket_subject and ticket_body
- problem_text and solution_text both reconstructed from followup content only
- Results in low-quality semantic representations for embedding and RAG
- Only Kaggle support datasets (customer_support_tickets_200k, dataset_tickets_multi_lang) retained

**Row Count Impact:**
- Before: 108,766 (79,999 customer_support + 28,537 multi_lang + 230 GLPI)
- After: 108,536 (79,999 customer_support + 28,537 multi_lang)
- Removed: 230 GLPI records

**Test Results:**
- 10/10 v2 tests PASS (accepted_values for source_dataset updated — removed 'GLPI')
- No regressions

**Schema Changes:**
- `gold/schema.yml`: accepted_values for source_dataset now only: customer_support_tickets_200k, dataset_tickets_multi_lang
- Column descriptions updated: urgency_tier, impact_tier, waiting_duration, followup_count, avg_followup_content_length marked as always NULL/0 (GLPI excluded)

**Lineage:**
- gloss: Silver_ticket_corpus (filtered source_system != 'GLPI') + Silver_triage_features → gold_ticket_similarity_v2
- No silver model modifications required — filter applied in gold model's first CTE
>>>>>>> Stashed changes
