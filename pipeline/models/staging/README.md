# 🧱 Staging Layer — Preparing Atomic Building Blocks

The staging layer is where we prepare clean, standardized, and reliable datasets from raw sources.
These models act as the **foundation for all downstream transformations (fct, marts, ML features).**

---

## 📂 Naming Convention

```
stg_[source]__[entity]s.sql
```

Example:

```
stg_glpi__tickets.sql
```

---

## 🎯 Purpose of the Staging Layer

* Clean and standardize raw data
* Ensure consistency across sources (2013, 2014, 2015)
* Prepare atomic, reusable datasets
* Detect and handle data quality issues early

---

## ✅ Standard Transformations Applied

### 1. Renaming

* `date` → `created_at`
* `solvedate` → `solved_at`
* `closedate` → `closed_at`
* `year` → `source_year`

---

### 2. Primary Key Creation

Because ticket IDs are **not globally unique across years**, we created a composite key:

```sql
CONCAT(year, '_', id) AS ticket_pk
```

---

### 3. Type Handling

* Avoided unsupported MySQL casting (`TIMESTAMP`)
* Used native datetime fields directly

---

### 4. Unioning Multiple Sources

Data comes from multiple GLPI databases:

* glpi_2013
* glpi_2014
* glpi_2015

These are combined in:

```
base_glpi_tickets
```

Then cleaned in:

```
stg_glpi_tickets
```

---

### 5. Data Cleaning (Critical Step)

#### 🚨 Problem Encountered

We detected invalid records:

```text
solved_at < created_at
```

Example:

```
created_at = 16:58
solved_at  = 14:13 ❌
```

---

#### ✅ Solution Implemented

Instead of deleting data, we **nullified invalid values**:

```sql
CASE 
    WHEN solvedate < date THEN NULL
    ELSE solvedate
END AS solved_at
```

Same logic applied to `closed_at`.

---

### 6. Optional Enhancement (Anomaly Tracking)

We introduced the possibility to track anomalies:

```sql
CASE 
    WHEN solvedate < date THEN 1
    ELSE 0
END AS is_solved_anomaly
```

This can be used later for:

* Data quality monitoring
* AI / anomaly detection

---

## 🧪 Data Quality Testing

We implemented both **schema tests** and **custom business tests**.

---

### ✅ Schema Tests

* `ticket_pk` → unique, not null
* `created_at` → not null
* `status` → not null
* `source_year` → accepted values (2013–2015)
* `is_deleted` → accepted values (0,1)

---

### ✅ Business Logic Tests

#### 1. Date Consistency

```sql
solved_at < created_at OR closed_at < created_at
```

---

#### 2. Non-negative Durations

```sql
waiting_duration < 0
```

---

#### 3. Delay Validity

```sql
close_delay_stat < 0
OR solve_delay_stat < 0
OR takeintoaccount_delay_stat < 0
```

---

#### 4. Deleted Flag Integrity

```sql
is_deleted NOT IN (0,1)
```

---

#### 5. Missing Critical Fields

```sql
created_at IS NULL OR ticket_id IS NULL
```

---

#### 6. Duplicate Tickets per Year

```sql
GROUP BY source_year, ticket_id HAVING COUNT(*) > 1
```

---

## ⚠️ Issues Faced & Fixes

| Issue                        | Cause                            | Solution                        |
| ---------------------------- | -------------------------------- | ------------------------------- |
| MySQL error with `TIMESTAMP` | Unsupported syntax               | Used `DATETIME` or raw fields   |
| `source_year` missing        | Not present in base model        | Replaced with `year`            |
| Duplicate IDs across years   | Same ticket IDs in different DBs | Created composite PK            |
| Invalid dates                | Dirty GLPI data                  | Nullified inconsistent values   |
| Failing dbt test             | Real data anomaly                | Fixed logic instead of ignoring |
| created_ad after solved_ad   | Dirty GLPI data                  | Fixed logic                     |
---

## ⚙️ Materialization Strategy

* Staging models are **materialized as views**

### Why?

* Always reflect latest data
* Avoid unnecessary storage
* Not intended for direct BI querying
* Lightweight and reusable

---

## 🧠 Key Design Principles

* ❌ No aggregations

* ❌ No filtering (e.g., last 30 days)

* ❌ No business KPIs

* ✅ Clean, atomic, reusable data

* ✅ Data quality enforced early

* ✅ Ready for downstream modeling

---

## 🚀 Next Steps

After staging:

```
stg_glpi_tickets
      ↓
fct_tickets (durations, SLA, KPIs)
      ↓
ml_features (AI / risk prediction)
```

---

## 💡 Final Insight

The staging layer is not just about cleaning data —
it is where **data reliability is guaranteed**.

Fixing issues here ensures:

* Accurate dashboards
* Reliable analytics
* Trustworthy AI models

---
