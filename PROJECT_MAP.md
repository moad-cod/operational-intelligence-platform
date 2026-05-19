# PROJECT MAP — ETL Pipeline

> **Project**: pfe-bachelor/etl — ELT pipeline for IT service management analytics (GLPI + OCS Inventory + Kaggle external datasets)

---

## [TECH_STACK]

| Category | Technology | Details |
|---|---|---|
| **Language** | Python 3.12 | `.python-version`; Airflow on 3.10 (Docker) |
| **Orchestration** | Apache Airflow 2.7.1 | LocalExecutor; 8 DAGs (7 manual, 1 `@daily`) |
| **Transformations** | dbt 1.7.19 | 22 staging views + 5 silver views = 27 models |
| **Warehouse** | MySQL 8.0 | `warehouse_db` service, database `it_data_warehouse` |
| **Source DB** | MySQL 8.0 | `platform_db` service with GLPI/OCS historical dumps (2013–2015) |
| **Airflow Metadata** | PostgreSQL 15 | `postgres` service |
| **Containerization** | Docker Compose | 4 services: `platform_db`, `warehouse_db`, `postgres`, `airflow` |
| **Package Manager** | `uv` | `pyproject.toml` + `uv.lock` |
| **Ingestion Libs** | pandas, SQLAlchemy, PyMySQL, mysql-connector-python | |
| **Airflow Providers** | `apache-airflow-providers-mysql` | |
| **dbt Adapter** | `dbt-mysql>=1.7.0` | |

---

## [SYSTEM_FLOW]

### ELT Pipeline

```
 Source Systems / Kaggle CSVs
           │
           ▼
 ┌──────────────────────┐
 │   BRONZE LAYER       │  ← Airflow DAGs + Python scripts
 │   (Raw Ingestion)    │    Load raw data into warehouse_db
 │                      │    Metadata: source_year, source_system
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │   STAGING LAYER      │  ← dbt SQL views
 │   (Cleaned & Std.)   │    Per-source cleaning, normalization,
 │                      │    surrogate keys, type casting
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │   SILVER LAYER       │  ← dbt SQL views (materialized)
 │   (Cross-Domain      │    Cross-source integration, dedup,
 │   Integration)       │    business rules, feature engineering,
 │                      │    dashboard-ready datasets
 └──────────┬───────────┘
            │
            ▼
 ┌──────────────────────┐
 │   GOLD LAYER         │  ← ❌ NOT YET IMPLEMENTED (mart_*)
 │   (Business / ML)    │    Aggregated KPIs, ML features
 └──────────────────────┘
```

### Data Sources & Ingestion

| Source | Years | DAG | Script | Target Tables |
|---|---|---|---|---|
| **GLPI ITSM** | 2013–2015 (3 DBs) | `glpi_bronze_ingestion` | `extract_glpi_bronze.py` | 10 `bronze_glpi_*` tables |
| **OCS Inventory** | 2013–2015 (3 DBs) | `ocs_bronze_ingestion` | `extract_ocs_bronze.py` | 7 `bronze_ocs_*` tables |
| **OCS Software** | 2013–2015 | `ocs_softwares_ingestion` (scheduled) | `ingest_ocs_softwares.py` | `bronze_ocs_software` |
| **Kaggle CVE** | N/A | `ingest_cve_kaggle` | `ingest_cve_kaggle.py` | `raw_cve_data` |
| **Kaggle Hard Drive** | N/A | `ingest_harddrive_kaggle` | `ingest_harddrive_kaggle.py` | `raw_harddrive_data` |
| **Kaggle Laptop Price** | N/A | `ingest_laptop_price_kaggle` | `ingest_laptop_price_kaggle.py` | `raw_laptop_price_data` |
| **Kaggle Tickets** | N/A | `ingest_tickets_kaggle` | `ingest_tickets_kaggle.py` | 2 raw tables |
| **Kaggle Windows Event** | N/A | `ingest_windows_eventlog_kaggle` | `ingest_windows_eventlog_kaggle.py` | `raw_windows_eventlog_data` |

### Staging Models Overview

| Domain | Models | Key Transformations |
|---|---|---|
| **GLPI** (10) | tickets, users, computers, logs, ticketfollowups, infocoms, deviceprocessors, devicememories, devicegraphiccards, itilcategories | Date cleaning, status booleans, SLA metrics, LDAP detection, HTML entity cleaning, CPU/GPU classification, asset value tiers |
| **OCS** (7) | hardware, bios, drives, memories, networks, storages, software | OS family, IP validation, drive type, BIOS age, memory speed tier, software dedup, risk scoring |
| **Kaggle** (5) | cve, harddrive, laptop_price, windows_eventlog, kaggle_tickets | CVSS severity, SMART health scoring, CPU/RAM parsing, suspicious event detection, multi-source union |

### Silver Models Overview

| Model | Sources | Purpose | Key Outputs |
|---|---|---|---|
| **silver_tickets** | `stg_glpi_tickets`, `stg_kaggle_tickets` | Unified cross-source ticket dataset | Standardized priority/status, deduped, is_closed, priority_score, complexity_level |
| **silver_assets** | `stg_ocs_hardware`, `stg_ocs_bios`, `stg_glpi_computers`, `stg_glpi_infocoms`, component models, `stg_ocs_software` | Unified asset inventory with risk scoring | Manufacturer, OS, hardware specs, asset_value, storage_summary, software_risk, asset_risk_score, health_status |
| **silver_security_events** | `stg_cve_kaggle`, `stg_windows_eventlog_kaggle`, `stg_glpi_tickets` | Unified security events | Normalized severity (1–5), CVSS scores, remote_exploitable flags, geo-context, event source classification |
| **silver_triage_features** | `silver_tickets` | ML feature engineering for triage | sla_risk_score, escalation_probability, triage_priority, customer_type, age_severity |
| **silver_user_activity** | `stg_glpi_users`, `stg_glpi_logs`, `stg_glpi_ticketfollowups`, `stg_ocs_hardware` | Unified user activity audit trail | Suspicious activity flags, activity_category (read/write), user_type, activity_type, entity context |

---

### Silver Layer Data Lineage

```
stg_glpi_tickets ───────────────────────────────────────┐
stg_kaggle_tickets ─────────────────────────────────────┤
                                                        ├──> silver_tickets ──> silver_triage_features
stg_glpi_itilcategories ────────────────────────────────┘
                                                                     │
stg_ocs_hardware ────────┐                                          │
stg_ocs_bios ────────────┤                                          │
stg_glpi_computers ──────┤──> silver_assets                         │
stg_glpi_infocoms ───────┤                                          │
stg_ocs_storages ────────┤                                          │
stg_ocs_drives ──────────┤                                          │
stg_ocs_software ────────┘                                          │
                                                                     ├──> GOLD (future)
stg_cve_kaggle ───────────────────────────────────────┐              │
stg_windows_eventlog_kaggle ──────────────────────────┤              │
                                                       ├──> silver_security_events
stg_glpi_tickets (security) ──────────────────────────┘              │
                                                                     │
stg_glpi_users ───────────────────────────────────┐                  │
stg_glpi_logs ────────────────────────────────────┤                  │
stg_glpi_ticketfollowups ─────────────────────────┤──> silver_user_activity
stg_ocs_hardware (logged_user) ───────────────────┘                  │
                                                                     │
                                                      silver_tickets ──> silver_triage_features
```

---

## [ARCHITECTURE]

### Directory Structure

```
etl/
├── main.py                         # Stub — not wired into pipeline
├── pyproject.toml / uv.lock        # Python dependencies
├── docker-compose.yml              # 4 services: platform_db, warehouse_db, postgres, airflow
├── .python-version                 # Python 3.12
│
├── airflow/
│   ├── Dockerfile                  # apache/airflow:2.7.1-python3.10
│   ├── dags/                       # 8 Airflow DAGs
│   │   ├── glpi_bronze_dag.py
│   │   ├── ocs_bronze_dag.py
│   │   ├── ocs_softwares_dag.py
│   │   ├── kaggle_cve_dag.py
│   │   ├── kaggle_harddrive_dag.py
│   │   ├── kaggle_laptop_price_dag.py
│   │   ├── kaggle_tickets_dag.py
│   │   └── kaggle_windows_eventlog_dag.py
│   ├── scripts/                    # 8 Python ingestion scripts
│   │   ├── extract_glpi_bronze.py
│   │   ├── extract_ocs_bronze.py
│   │   ├── ingest_ocs_softwares.py
│   │   ├── ingest_cve_kaggle.py
│   │   ├── ingest_harddrive_kaggle.py
│   │   ├── ingest_laptop_price_kaggle.py
│   │   ├── ingest_tickets_kaggle.py
│   │   └── ingest_windows_eventlog_kaggle.py
│   └── data/                       # 7 data files
│       ├── cve.csv, harddrive.csv, laptop_price.csv
│       ├── windows_eventlog.csv
│       ├── customer_support_tickets_200k.csv
│       ├── dataset-tickets-multi-lang.csv
│       └── Linux_2k.log            # ❌ Orphaned — no ingestion script
│
├── pipeline/                       # dbt project
│   ├── dbt_project.yml
│   ├── models/
│   │   ├── source.yml              # Bronze table definitions
│   │   ├── staging/
│   │   │   ├── schema.yml          # Column-level tests & docs (1778 lines)
│   │   │   ├── glpi/               # 10 staging SQL models
│   │   │   ├── ocs/                # 7 staging SQL models
│   │   │   └── kaggle/             # 5 staging SQL models
│   │   └── silver/                 # ✅ Silver Layer (5 models)
│   │       ├── schema.yml          # Silver column tests & docs
│   │       ├── silver_tickets.sql
│   │       ├── silver_assets.sql
│   │       ├── silver_security_events.sql
│   │       ├── silver_triage_features.sql
│   │       └── silver_user_activity.sql
│   ├── tests/
│   │   ├── staging/
│   │   │   ├── glpi/               # 10 test files (1 missing _test suffix)
│   │   │   ├── ocs/                # 7 test files (1 with copy-paste bug)
│   │   │   └── kaggle/             # 5 test files
│   │   └── silver/                 # 8 custom silver tests
│   │       ├── silver_tickets_priority_consistency.sql
│   │       ├── silver_tickets_future_date_check.sql
│   │       ├── silver_assets_os_family_consistency.sql
│   │       ├── silver_assets_risk_consistency.sql
│   │       ├── silver_security_severity_consistency.sql
│   │       ├── silver_triage_sla_range.sql
│   │       ├── silver_triage_escalation_range.sql
│   │       └── silver_user_activity_valid_dates.sql
│   ├── analyses/                   # Empty
│   ├── seeds/                      # Empty
│   ├── snapshots/                  # Empty
│   ├── macros/                     # Empty (contains only .gitkeep)
│   ├── target/                     # Compiled dbt artifacts
│   └── logs/                       # dbt run logs
│
├── source_db_init/
│   ├── grants.sql
│   ├── GLPI_OCS_2013.12.31_23.30.30.sql  # ~9679 lines
│   ├── GLPI_OCS_2014.12.31_23.30.30.sql  # ~9701 lines
│   └── GLPI_OCS_2015.11.22_23.30.30.sql  # ~9700 lines
│
├── logs/                            # Airflow task logs
└── .vscode/settings.json
```

### Key Patterns

- **Composite PKs**: `CONCAT(source_year, '_', id)` to deduplicate IDs across 2013–2015 sources
- **Surrogate Keys**: MD5 for Kaggle/OCS software models; MD5(CONCAT('PREFIX_', pk)) for silver cross-source keys
- **Materialization**: Staging as **views**, Silver configured as **views** (config in dbt_project.yml; can be changed to `table` for performance)
- **Multi-Source Union**: `stg_kaggle_tickets` unions 2 heterogeneous CSV datasets with NULL padding
- **Cross-Source Dedup**: `ROW_NUMBER() OVER (PARTITION BY business_key ORDER BY updated_at DESC)` in all silver models
- **Derived Feature Scoring**: SLA risk (0–10), escalation probability (0–10), priority score (1–5) in silver_triage_features
- **Risk Classification**: Multi-factor asset risk combining BIOS age, software vulnerabilities, drive health
- **Incremental Load**: Kaggle scripts `replace` first chunk, `append` rest
- **Hardcoded Credentials**: All scripts embed `warehouse:warehouse_pass` / `mouad:secret`

---

## [SILVER ARCHITECTURE]

### Design Principles

1. **Cross-Source Integration**: Each silver model unifies data from ≥2 staging sources
2. **Deduplication First**: `ROW_NUMBER()` windows eliminate duplicates before enrichment
3. **Standardized Enums**: All categorical fields use controlled vocabularies (critical/high/medium/low)
4. **Derived Scoring**: Business rules produce numeric scores for ML consumption
5. **No Raw Data Leakage**: Silver never references bronze tables directly — always through staging
6. **Schema-on-Test**: Every column has at least one schema test (not_null, unique, accepted_values)

### Transformation Rules

| Rule | Implementation |
|---|---|
| **Deduplication** | `ROW_NUMBER() OVER (PARTITION BY business_key ORDER BY last_updated DESC) WHERE rn = 1` |
| **Null Handling** | `COALESCE()`, `NULLIF(TRIM()), ''`, `CASE WHEN col <= 0 THEN NULL END` |
| **Type Casting** | Explicit `CAST()` with validity checks (e.g., `CASE WHEN CAST(col AS CHAR) = '0000-00-00' THEN NULL END`) |
| **Priority Mapping** | All sources map to: critical(5), high(4), medium(3), low(2), unknown(1) |
| **Status Mapping** | GLPI numeric→text + Kaggle text → unified set: open, in_progress, resolved, closed, escalated |
| **Cross-Source Joins** | UUID (preferred) → hostname (fallback) → source_year partition |
| **Aggregation** | Component counts (CPU/memory/storage) rolled up per asset via GROUP BY + SUM/COUNT |
| **Risk Scoring** | Multi-factor: BIOS age × software risk × drive health × asset value |

### Data Contracts

| Contract | Definition | Enforced In |
|---|---|---|
| **PK uniqueness** | Every silver model has a unique, not_null PK | schema.yml (unique + not_null) |
| **Enum bounds** | All categorical fields defined via accepted_values | schema.yml (accepted_values) |
| **Score ranges** | Numeric scores bounded (0–10 for risk, 1–5 for priority) | Custom SQL tests |
| **Referential integrity** | Foreign keys point to existing silver PKs | relationships tests |
| **No future dates** | Timestamps must not exceed CURRENT_DATE + 1d | Custom SQL tests |
| **Consistency** | Derived fields must align with source fields (e.g., priority_score ↔ priority) | Custom SQL tests |

### Validation Strategy

| Layer | Test Type | Count | Location |
|---|---|---|---|
| **Schema** | not_null, unique, accepted_values | ~60 tests | `models/silver/schema.yml` |
| **Business** | Custom SQL (consistency, ranges, referential) | 8 tests | `tests/silver/*.sql` |
| **Counts** | Row count parity with staging (no unexpected drops) | Manual | dbt run + audit |
| **Regression** | Existing staging/bronze tests unchanged | N/A | Pipeline CI |

### Quality Metrics

| Metric | Target | Measurement |
|---|---|---|
| **Duplicate rate** | 0% | unique PK tests |
| **Null rate on key fields** | < 1% | not_null tests on business keys |
| **Enum compliance** | 100% | accepted_values tests |
| **Score validity** | 100% in range | Custom range checks (0–10, 1–5) |
| **Date validity** | No future dates | Custom date checks |

### Dashboard Mapping

| Dashboard Component | Silver Model(s) | Gold Dependency |
|---|---|---|
| **TriageFeed** | silver_tickets, silver_triage_features | — |
| **SolutionRecommender** | silver_tickets (ticket_subject, ticket_body) | Needs NLP embedding |
| **AssetRiskTable** | silver_assets | — |
| **SecurityClusters** | silver_security_events | Needs time-series aggregation |
| **FailureQueue** | silver_triage_features (escalation_probability) | Needs threshold config |
| **ActivityGraph** | silver_user_activity | — |
| **UsageRadar** | silver_user_activity (activity_category, user_type) | Needs aggregation by time |

---

## [ORPHANS & PENDING]

### 🚫 Missing Layers (Blockers)

| Item | Location | Impact |
|---|---|---|
| **Gold Layer** (`mart_*`) | `pipeline/models/gold/` — does not exist | No aggregated KPIs or ML-ready feature sets |
| **`profiles.yml`** | Root or `~/.dbt/` — missing (gitignored) | Cannot run dbt without manual setup |

### 🔴 Test Issues

| Issue | File | Details |
|---|---|---|
| **Duplicate PK test fails** | `stg_ocs_software` | `unique_stg_ocs_software_software_pk` fails: 41,885 duplicate rows — MD5 surrogate key is not unique |
| **Column mismatch in schema** | `pipeline/models/staging/schema.yml` | Tests reference columns not produced by SQL models (e.g., `disk_risk_level`, `device_status`, `is_ecc`, `frequency_mhz`) → ~60 Database Errors |
| **Copy-paste bug** | `pipeline/tests/staging/ocs/stg_ocs_storages_test.sql` | `FROM {{ ref('stg_ocs_software') }}` — should reference `stg_ocs_storages` |
| **Test file naming** | `pipeline/tests/staging/glpi/stg_glpi_computers.sql` | Missing `_test` suffix (all others follow `*_test.sql` convention) |
| **dbt_project.yml silver config** | `pipeline/dbt_project.yml` | Silver is configured as `+materialized: view` but documentation says "tables" |

### 🧹 Code Quality / Technical Debt

| Issue | Details |
|---|---|
| **Hardcoded credentials** | All 8 Python scripts embed MySQL passwords in plain text |
| **Duplicate ingestion code** | 4 Kaggle scripts share identical pattern — should be refactored into a shared module |
| **Missing error handling** | Kaggle scripts only check file existence; no retry, alerting, or structured logging |
| **Hostname inconsistency** | `extract_ocs_bronze.py` uses `glpi_ocs_db` (container_name), `ingest_ocs_softwares.py` uses `platform_db` (service_name) — different Docker networking resolution |
| **`main.py` stub** | Root `main.py` only prints "Hello from pfe-bachelor!" — not wired into any workflow |

### 🗑️ Orphaned / Unused Files

| File | Reason |
|---|---|
| `airflow/data/Linux_2k.log` | No ingestion script references this log file |
| `pipeline/models/staging/README.md` | Contains scratch git notes, not documentation |
| `main.py` | Stub file with no pipeline integration |
| `pipeline/README.md` | Default dbt README (not customized) |

### 📋 Pending Enhancements

| Item | Priority | Notes |
|---|---|---|
| Implement Gold/Mart models | High | Needed for analytics/ML use cases |
| Verify silver models against live data | High | Not yet run against warehouse; schema.yml and tests need validation |
| Fix dbt test failures (staging) | High | ~60 tests fail due to schema mismatches and duplicate PKs |
| Change silver materialization to `table` | Medium | Currently `view` in dbt_project.yml; tables would improve query performance |
| Extract shared ingestion module | Medium | Reduce duplicate Kaggle code |
| Move credentials to env/connections | Medium | Security best practice |
| Add sentiment scoring to silver_tickets | Medium | Currently NULL — needs NLP integration from followup content |
| Add geo-enrichment to silver_security_events | Medium | Country data exists but IP→geo mapping incomplete |
| Join silver_tickets to silver_user_activity | Low | Not yet linked (user_id → ticket_id relationship exists) |
| Fix `stg_ocs_storages` test SQL | Low | `FROM` points to wrong model |
| Rename `stg_glpi_computers.sql` test | Low | Missing `_test` suffix |
