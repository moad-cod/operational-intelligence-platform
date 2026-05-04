# 🧱 Intermediate Layer — Feature Engineering (Silver Layer)

The **Intermediate (Silver) layer** transforms clean, standardized data into meaningful, business-ready features.

![DAG Overview](/pipeline/models/intermediate/DAG.png)

It acts as a bridge between:

| Layer | Role |
|-------|------|
| 🧼 **Staging Layer** | Cleaned & standardized data |
| 🥈 **Intermediate Layer** | Feature engineering & business logic |
| 🏆 **Gold Layer** | Analytics, BI, and ML-ready models |

---

## 📂 Project Structure

```
models/intermediate/
├── device_activity/
│   └── int_device_activity.sql
│
├── performance/
│   └── int_device_performance.sql
│
├── storage/
│   └── int_device_storage.sql
│
├── tickets/
│   └── int_ticket_features.sql
│
├── schema.yml
└── README.md
```

---

## 🎯 Purpose

This layer converts raw data into usable signals:

- ✔️ Feature engineering
- ✔️ Aggregations
- ✔️ Business logic
- ✔️ Signal extraction
- ✔️ ML-ready dataset preparation

---

## 🔥 Models Overview

### 🧠 Device Activity — `int_device_activity.sql`

**Source:** `stg_ocs_hardware`  
**Goal:** Measure device usage and activity

**Features**

| Feature | Description |
|---------|-------------|
| `last_seen_at` | Timestamp of last device contact |
| `activity_score` | Computed activity rating |
| `is_active_flag` | Boolean activity indicator |
| `device_status` | Categorical status label |

**Logic**

```sql
CASE
    WHEN last_seen_at >= DATE_SUB(max_date, INTERVAL 7 DAY)  THEN 'active'
    WHEN last_seen_at >= DATE_SUB(max_date, INTERVAL 30 DAY) THEN 'inactive'
    ELSE 'stale'
END
```

---

### 💾 Device Storage — `int_device_storage.sql`

**Source:** `stg_ocs_drives`  
**Goal:** Detect storage risks

**Features**

| Feature | Description |
|---------|-------------|
| `total_storage_gb` | Total disk capacity |
| `avg_usage_ratio` | Average utilization across disks |
| `max_usage_ratio` | Peak utilization (worst disk) |
| `disk_count` | Number of disks |
| `critical_disk_flag` | `true` when any disk exceeds threshold |

**Rule**

```
usage_ratio > 0.9  →  critical
```

---

### ⚙️ Device Performance — `int_device_performance.sql`

**Sources**

- `stg_glpi_deviceprocessors`
- `stg_glpi_devicememories`
- `stg_glpi_devicegraphiccards`

**Goal:** Evaluate hardware performance

**Output schema**

| Column | Description |
|--------|-------------|
| `component_type` | CPU / Memory / GPU |
| `performance_score` | Numeric score (0–3) |
| `performance_tier` | Low / Medium / High |

**Scoring logic**

| Component | Metric |
|-----------|--------|
| CPU | Performance tier from model |
| Memory | Size in GB |
| GPU | VRAM + type |

> ⚠️ **Design Choice:** GLPI and OCS are not directly linked — GLPI tracks components, OCS tracks devices. Performance is therefore modeled at the **component level** to avoid forced, unreliable joins. Merging happens in the Gold layer.

---

### 🎫 Ticket Features — `int_ticket_features.sql`

**Sources:** `stg_glpi_tickets`, `stg_glpi_ticketfollowups`  
**Goal:** Extract behavioral signals from support tickets

**Features**

| Feature | Description |
|---------|-------------|
| `followup_count` | Number of follow-ups |
| `duration_days` | Ticket lifespan in days |
| `positive_signals` | Count of resolved-like keywords |
| `negative_signals` | Count of error-like keywords |
| `is_resolved_flag` | Boolean resolution indicator |

**Signal extraction**

```sql
LOWER(content) LIKE '%resolved%'   -- positive signal
LOWER(content) LIKE '%error%'      -- negative signal
```

---

## 🧪 Data Quality

### ✅ Schema Tests

- `not_null`
- `accepted_values`
- `unique`

### ✅ Business Tests

- `performance_score` must be `BETWEEN 0 AND 3`
- Invalid tier combinations flagged
- `usage_ratio > 1` detected as anomaly

---

## ⚠️ Key Design Decisions

### 1. GLPI vs OCS Separation

There is no direct mapping between GLPI and OCS data sources.

**Solution:** Keep models separate at the intermediate layer and merge in the Gold layer.

### 2. Avoid Cartesian Explosion

Cross-joining CPU × RAM × GPU produces an unmanageable result set.

**Solution:** Use component-level modeling — one row per component, not per device.

### 3. Real-World Data Handling

| Challenge | Approach |
|-----------|----------|
| Low RAM distribution | Adjusted scoring thresholds |
| Missing GPU VRAM | Safe null handling |
| Null values across sources | Defaults applied consistently |

---

## ⚙️ Materialization

```yaml
materialized: view
```

**Why views?**

- Lightweight — no storage overhead
- Always up-to-date
- Fast iteration during development
- Transparent query logic

---

## 🧠 Design Principles

| Included ✔️ | Not Included ❌ |
|-------------|----------------|
| Feature engineering | Data cleaning (→ Staging) |
| Aggregations | Business KPIs (→ Gold) |
| Signal extraction | Raw source joins |
| Consistent transformations | Final reporting logic |

---

## 🚀 What This Enables

### 🏆 Gold Layer

- `dim_devices`
- `fct_tickets`
- `device_health_score`

### 🤖 Machine Learning

- Risk prediction
- Failure detection
- Ticket escalation modeling

### 📊 BI & Dashboards

- Device performance monitoring
- Storage risk tracking
- Ticket analytics

---

## 🎯 Final Insight

```
Staging      →  clean data
Intermediate →  smart data
Gold         →  business data
```

> **This is the layer where data becomes valuable.**
