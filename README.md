# PFE Bachelor — ETL Pipeline

> ELT pipeline for IT service management analytics. Ingests, cleans, and integrates IT infrastructure data from **GLPI ITSM**, **OCS Inventory**, and **Kaggle external datasets** (CVEs, Windows events, hard drive SMART metrics, laptop pricing, customer support tickets).

---

## Table of Contents

- [Project Overview](#1-project-overview)
- [Architecture Overview](#2-architecture-overview)
- [Tech Stack](#3-tech-stack)
- [Project Structure](#4-project-structure)
- [Data Architecture](#5-data-architecture)
- [Dashboard Modules](#6-dashboard-modules)
- [Setup Instructions](#7-setup-instructions)
- [Development Workflow](#8-development-workflow)
- [Known Limitations](#9-known-limitations)
- [Future Roadmap](#10-future-roadmap)

---

## 1. Project Overview

### Business Use-Case

An IT department manages thousands of assets (computers, servers, peripherals) and resolves tens of thousands of support tickets across multiple years. The data is spread across:

- **GLPI ITSM** — Ticketing system, IT asset management, audit logs (2013–2015)
- **OCS Inventory** — Hardware/software inventory from network scans (2013–2015)
- **Kaggle Datasets** — External security (CVE, Windows events), hardware reliability (SMART), and customer support data

### Goals

- Build a centralized **Data Warehouse** (`it_data_warehouse`) that unifies all sources
- Clean and standardize raw data through **dbt transformations**
- Create **Silver Layer** datasets ready for Analytics, AI/ML, and Dashboard consumption
- Future: Build Gold Layer for KPIs, predictions, and NLP-based triage

### AI & Analytics Capabilities (Future)

- Predictive maintenance from hard drive SMART metrics + OCS inventory
- Ticket auto-classification and sentiment analysis
- Security event clustering from CVE + Windows event logs
- Escalation prediction and SLA risk scoring (silver_triage_features)

---

## 2. Architecture Overview

### Full Pipeline Flow

```
 Source Systems / Kaggle CSVs
           │
           ▼
 ┌──────────────────────┐
 │   BRONZE LAYER       │  ← Airflow DAGs + Python scripts
 │   (Raw Ingestion)    │    22 bronze tables in MySQL warehouse
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │   STAGING LAYER      │  ← dbt views (22 models)
 │   (Cleaned & Std.)   │    Per-source cleaning, normalization,
 │                      │    surrogate keys, type casting
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │   SILVER LAYER       │  ← dbt views (5 models)
 │   (Cross-Domain      │    Cross-source integration, dedup,
 │    Integration)      │    business rules, feature engineering
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │   GOLD LAYER         │  ← ❌ Not yet implemented
 │   (Business / ML)    │    Aggregated KPIs, ML features
 └──────────────────────┘
```

### Components

| Component | Role |
|-----------|------|
| **Airflow** | Orchestrates ingestion DAGs (8 DAGs, 7 manual + 1 scheduled) |
| **dbt** | SQL transformations across 27 models (22 staging + 5 silver) |
| **MySQL (warehouse_db)** | Central data warehouse (`it_data_warehouse` database) |
| **MySQL (platform_db)** | Source databases with GLPI/OCS historical dumps |
| **PostgreSQL** | Airflow metadata storage |
| **Docker Compose** | 4-service infrastructure (platform_db, warehouse_db, postgres, airflow) |

---

## 3. Tech Stack

| Category | Technology | Version |
|----------|-----------|---------|
| **Language** | Python | 3.12 (host), 3.10 (Airflow Docker) |
| **Orchestration** | Apache Airflow | 2.7.1 (LocalExecutor) |
| **Transformations** | dbt (Data Build Tool) | 1.7.19 |
| **Warehouse** | MySQL | 8.0 |
| **Source Database** | MySQL | 8.0 |
| **Airflow Metadata** | PostgreSQL | 15 |
| **Containerization** | Docker / docker-compose | — |
| **Package Manager** | `uv` | — |
| **dbt Adapter** | `dbt-mysql` | ≥1.7.0 |
| **Ingestion Libraries** | pandas, SQLAlchemy, PyMySQL, mysql-connector-python | — |
| **Airflow Providers** | `apache-airflow-providers-mysql` | — |

---

## 4. Project Structure

```
etl/
├── main.py                         # Stub entry point (not wired)
├── pyproject.toml                  # Python project config + dependencies
├── docker-compose.yml              # 4 services (platform_db, warehouse_db, postgres, airflow)
├── .python-version                 # Python 3.12
│
├── airflow/
│   ├── Dockerfile                  # apache/airflow:2.7.1-python3.10 + Python deps
│   ├── dags/                       # 8 Airflow DAGs
│   │   ├── glpi_bronze_dag.py      # GLPI bronze ingestion (manual)
│   │   ├── ocs_bronze_dag.py       # OCS bronze ingestion (manual)
│   │   ├── ocs_softwares_dag.py    # OCS software extraction (scheduled @daily)
│   │   ├── kaggle_cve_dag.py       # CVE data ingestion (manual)
│   │   ├── kaggle_harddrive_dag.py # Hard drive SMART ingestion (manual)
│   │   ├── kaggle_laptop_price_dag.py # Laptop pricing ingestion (manual)
│   │   ├── kaggle_tickets_dag.py   # Customer support tickets (manual)
│   │   └── kaggle_windows_eventlog_dag.py # Windows event logs (manual)
│   ├── scripts/                    # 8 Python ingestion scripts
│   │   ├── extract_glpi_bronze.py  # Extracts 10 GLPI tables from 3 yearly DBs
│   │   ├── extract_ocs_bronze.py   # Extracts 7 OCS tables from 3 yearly DBs
│   │   ├── ingest_ocs_softwares.py # Extracts software inventory
│   │   ├── ingest_cve_kaggle.py    # CVE CSV → raw_cve_data
│   │   ├── ingest_harddrive_kaggle.py # Hard drive CSV → raw_harddrive_data
│   │   ├── ingest_laptop_price_kaggle.py # Laptop CSV → raw_laptop_price_data
│   │   ├── ingest_tickets_kaggle.py # 2 CSVs → customer_support_tickets_200k + dataset_tickets_multi_lang
│   │   └── ingest_windows_eventlog_kaggle.py # Event CSV → raw_windows_eventlog_data
│   └── data/                       # 6 CSV + 1 log file (~785 MB total)
│       ├── cve.csv                 # CVE vulnerabilities
│       ├── harddrive.csv           # Hard drive SMART metrics (largest: 579 MB)
│       ├── laptop_price.csv        # Laptop pricing
│       ├── windows_eventlog.csv    # Windows security events
│       ├── customer_support_tickets_200k.csv
│       ├── dataset-tickets-multi-lang.csv
│       └── Linux_2k.log            # ⚠️ Orphaned — no ingestion script
│
├── pipeline/                       # dbt project (primary transformation layer)
│   ├── dbt_project.yml             # 22 staging views + 5 silver views
│   ├── models/
│   │   ├── source.yml              # 22 bronze source table definitions
│   │   ├── staging/                # Per-source cleaning layer
│   │   │   ├── schema.yml          # 1778-line column-level tests
│   │   │   ├── glpi/               # 10 models (tickets, users, computers, logs, etc.)
│   │   │   ├── ocs/                # 7 models (hardware, bios, drives, etc.)
│   │   │   └── kaggle/             # 5 models (cve, harddrive, laptop, events, tickets)
│   │   └── silver/                 # Cross-domain integration layer
│   │       ├── schema.yml          # Column-level tests for silver models
│   │       ├── silver_tickets.sql  # Unified tickets (GLPI + Kaggle)
│   │       ├── silver_assets.sql   # Unified asset inventory with risk scoring
│   │       ├── silver_security_events.sql # Unified security events
│   │       ├── silver_triage_features.sql # ML-ready feature engineering
│   │       └── silver_user_activity.sql   # User activity audit trail
│   ├── tests/
│   │   ├── staging/glpi/           # 10 test files
│   │   ├── staging/ocs/            # 7 test files
│   │   ├── staging/kaggle/         # 5 test files
│   │   └── silver/                 # 8 custom SQL tests
│   ├── macros/                     # Empty (contains .gitkeep)
│   ├── analyses/                   # Empty
│   ├── seeds/                      # Empty
│   ├── snapshots/                  # Empty
│   └── target/                     # Compiled dbt artifacts
│
├── source_db_init/
│   ├── grants.sql                  # MySQL grants for user 'mouad'
│   ├── GLPI_OCS_2013.12.31_23.30.30.sql  # ~9679 lines
│   ├── GLPI_OCS_2014.12.31_23.30.30.sql  # ~9701 lines
│   └── GLPI_OCS_2015.11.22_23.30.30.sql  # ~9700 lines
│
├── logs/                            # Airflow task + dbt logs
└── .vscode/settings.json
```

---

## 5. Data Architecture

### Bronze Layer (Raw Ingestion)

22 raw tables in `it_data_warehouse`. Ingested by Airflow DAGs → Python scripts from:
- **GLPI ITSM** (10 tables): tickets, users, computers, logs, ticketfollowups, infocoms, deviceprocessors, devicememories, devicegraphiccards, itilcategories
- **OCS Inventory** (7 tables): hardware, bios, drives, software, memories, networks, storages
- **Kaggle Datasets** (5 tables): cve_data, windows_eventlog_data, harddrive_data, laptop_price_data, support tickets (2 tables)

### Staging Layer (22 dbt views)

Per-source cleaning and normalization. Key transformations:
- **Composite PKs**: `CONCAT(source_year, '_', id)` for cross-year uniqueness
- **Surrogate Keys**: MD5 hashes for Kaggle and OCS software
- **Date cleaning**: Nullify `0000-00-00`, invalid ranges, future dates
- **Type casting**: Explicit CAST with validity guards
- **Categorization**: CPU family, GPU brand, OS family, storage type, software category
- **Scoring**: Performance tiers, memory tiers, risk levels, SLA metrics
- **Multi-source union**: `stg_kaggle_tickets` unions 2 heterogeneous CSV datasets

### Silver Layer (5 dbt views)

Cross-domain integration with business rules and feature engineering:

| Model | Purpose | Key Outputs |
|---|---|---|
| `silver_tickets` | Unified tickets across GLPI + Kaggle | Standardized priority/status, priority_score, complexity_level |
| `silver_assets` | Unified asset inventory with risk | Manufacturer, OS, device_age, asset_risk_score, health_status |
| `silver_security_events` | Unified CVE + Windows events + security tickets | Normalized severity (1–5), remote_exploit flags, geo |
| `silver_triage_features` | ML features from tickets | sla_risk_score, escalation_probability, triage_priority |
| `silver_user_activity` | User activity audit trail | Suspicious activity flags, activity_category, user_type |

### Data Lineage

```
Bronze Tables → Staging Views → Silver Views → (future) Gold
                    │                │
              22 staging SQL     5 silver SQL + 8 custom tests
              + 1778 schema tests
```

---

## 6. Dashboard Modules

The Silver Layer is designed to directly feed 7 dashboard modules:

| Module | Source | Dependency |
|---|---|---|
| **TriageFeed** | silver_tickets + silver_triage_features | — |
| **SolutionRecommender** | silver_tickets (text fields) | Needs NLP embedding |
| **AssetRiskTable** | silver_assets | — |
| **SecurityClusters** | silver_security_events | Needs time-series aggregation |
| **FailureQueue** | silver_triage_features (escalation_probability) | Needs threshold config |
| **ActivityGraph** | silver_user_activity | — |
| **UsageRadar** | silver_user_activity | Needs time aggregation |

---

## 7. Setup Instructions

### Prerequisites

- Docker & Docker Compose
- Python 3.12 (for local dbt development)
- `uv` package manager

### 1. Start Infrastructure

```bash
docker-compose up -d
```

This starts:
- `platform_db` (MySQL 8.0, port 3307) — pre-loaded with GLPI/OCS historical dumps
- `warehouse_db` (MySQL 8.0, port 3308) — empty `it_data_warehouse` database
- `postgres` (PostgreSQL 15, port 5432) — Airflow metadata
- `airflow` (Airflow 2.7.1, port 8080) — webserver + scheduler

### 2. Access Airflow

- URL: http://localhost:8080
- Credentials: `admin` / `admin`

### 3. Run Ingestion DAGs

In Airflow UI, trigger DAGs in order:

1. `glpi_bronze_ingestion` — loads 10 GLPI bronze tables
2. `ocs_bronze_ingestion` — loads 7 OCS bronze tables
3. `ocs_softwares_ingestion` — loads OCS software (already scheduled `@daily`)
4. `ingest_cve_kaggle` through `ingest_windows_eventlog_kaggle` — 5 Kaggle datasets

### 4. Run dbt Transformations

Create a `profiles.yml` in `~/.dbt/`:

```yaml
pipeline:
  target: dev
  outputs:
    dev:
      type: mysql
      server: localhost
      port: 3308
      database: it_data_warehouse
      schema: it_data_warehouse
      username: warehouse
      password: warehouse_pass
```

Then run:

```bash
cd pipeline
dbt run
dbt test
```

### 5. dbt Commands Reference

| Command | Purpose |
|---|---|
| `dbt run` | Build all models |
| `dbt run --select staging` | Build only staging models |
| `dbt run --select silver` | Build only silver models |
| `dbt test` | Run all schema + custom tests |
| `dbt test --select silver_assets` | Test specific model |
| `dbt docs generate` | Generate documentation site |
| `dbt docs serve` | Serve documentation at http://localhost:8080 |
| `dbt ls` | List all models with their tags/selectors |

---

## 8. Development Workflow

### Naming Conventions

| Layer | Prefix | Materialization |
|---|---|---|
| Staging | `stg_<source>_<entity>` | view |
| Silver | `silver_<domain>` | view (configurable to table) |
| Gold (future) | `mart_<kpi>` | table / incremental |

### Model Lifecycle

1. Design: Define business purpose and success criteria
2. Build: Write SQL in appropriate `models/` subdirectory
3. Test: Add schema tests in `schema.yml` + custom SQL in `tests/`
4. Validate: Run `dbt run` + `dbt test`
5. Document: Update `PROJECT_MAP.md` with architecture and lineage

### Testing Strategy

| Test Type | Location | Examples |
|---|---|---|
| Schema tests | `schema.yml` | not_null, unique, accepted_values |
| Custom SQL tests | `tests/` | Range checks, consistency, referential integrity |
| Manual validation | Audit queries | Row counts, null ratios, business logic |

### Branching Strategy

- Direct commits on `main` for solo development
- After each stable milestone, verify with `dbt run && dbt test`

---

## 9. Known Limitations

| Limitation | Impact | Status |
|---|---|---|
| **`profiles.yml` missing** | Cannot run dbt without manual setup | Always (gitignored) |
| **Hardcoded credentials** | All Python scripts embed passwords | Needs env/connections |
| **~60 dbt test failures** | Schema mismatches between schema.yml and SQL models | Known |
| **OCS software duplicate PK** | `unique_stg_ocs_software_software_pk` fails: 41,885 duplicates | Known |
| **`stg_ocs_storages_test.sql` bug** | References wrong model (`stg_ocs_software`) | Needs fix |
| **No Gold layer** | No aggregated KPIs or ML-ready outputs | Future |
| **Sentiment analysis** | silver_tickets has NULL sentiment fields | Needs NLP integration |
| **`Linux_2k.log` orphaned** | File exists but no ingestion script uses it | Needs DAG or cleanup |
| **Mock data** | Source DB re-initializes from SQL dumps on container restart | — |
| **No authentication** | Airflow has simple admin/admin credentials only | — |
| **No real-time support** | Batch ELT only | — |

---

## 10. Future Roadmap

| Phase | Items |
|---|---|
| **Phase 1 — Stability** | Fix all dbt test failures, fix `stg_ocs_storages_test.sql`, rename test file, change silver to `table` materialization |
| **Phase 2 — Gold Layer** | Build aggregate models for KPIs, ML datasets, time-series features |
| **Phase 3 — ML Integration** | Sentiment scoring on tickets, security event clustering, failure prediction from SMART data |
| **Phase 4 — Production** | Move credentials to Airflow connections / env vars, add CI/CD, add observability (logging, alerting) |
| **Phase 5 — Hardening** | Add incremental models, snapshot support, dbt docs site, automated data quality checks with dbt-expectations |

---

## References

- [PROJECT_MAP.md](./PROJECT_MAP.md) — Complete architecture reference, dependency graph, orphan tracking
- [dbt Documentation](https://docs.getdbt.com)
- [Apache Airflow Documentation](https://airflow.apache.org/docs/)