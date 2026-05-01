# 🧱 Staging Layer — Atomic Data Foundation

The staging layer transforms raw data from **GLPI** and **OCS** into clean, standardized, and reliable datasets.

It acts as the **foundation of the data pipeline**, ensuring that all downstream models (analytics, dashboards, ML) are built on trusted data.

![alt text](image.png)

---

# 📂 Project Structure

```
models/
  
  staging/
    base/
        glpi/
        ocs/
    glpi/
    ocs/

tests/
  glpi/
  ocs/
```

---

# 🏷️ Naming Convention

```
stg_[source]__[entity].sql
```

### Examples:

* `stg_glpi__tickets.sql`
* `stg_glpi__ticketfollowups.sql`
* `stg_ocs__hardware.sql`
* `stg_ocs__drives.sql`

---

# 🎯 Objectives

The staging layer is responsible for:

* Cleaning raw data
* Standardizing column names and formats
* Handling multi-source datasets (2013–2015)
* Generating stable primary keys
* Detecting and managing data quality issues
* Preparing atomic datasets for reuse

---

# 🔧 Core Transformations

## 1. Column Standardization

| Raw         | Staged        |
| ----------- | ------------- |
| `date`      | `created_at`  |
| `solvedate` | `solved_at`   |
| `closedate` | `closed_at`   |
| `year`      | `source_year` |

---

## 2. Composite Primary Keys

IDs are not unique across years → we build:

```sql
CONCAT(year, '_', id) AS <entity>_pk
```

---

## 3. Multi-Source Integration

Data comes from:

* `glpi_2013`
* `glpi_2014`
* `glpi_2015`

Handled in:

```
base_* → stg_*
```

---

## 4. Data Cleaning (Critical)

### Example: Invalid Dates

```
solved_at < created_at ❌
```

### Solution:

```sql
CASE 
    WHEN solvedate < date THEN NULL
    ELSE solvedate
END
```

---

## 5. Text Cleaning

* Removed empty values (`''`, `'-'`)
* Cleaned HTML (`&gt;`)
* Applied `TRIM`, `LOWER`

---

## 6. Boolean Normalization

```sql
CASE WHEN is_private = 1 THEN 1 ELSE 0 END
```

---

# 💻 OCS Hardware Enrichment

## CPU

* Extracted core count from raw string
* Normalized architecture (`x86`, `x64`)

## RAM

* Converted MB → GB
* Created tiers:

  * `invalid_or_legacy`
  * `low`
  * `medium`
  * `high`

## Drives

* Computed:

  * `total_gb`, `used_gb`, `free_gb`
  * `usage_ratio`
* Classified:

  * `disk`, `cdrom`, `removable`
* Added:

  * `disk_risk_level` 🚨

## BIOS

* Cleaned serial numbers
* Parsed multiple date formats
* Computed:

  * `bios_age_years`

---

# ⚡ Activity Classification

Instead of static rules, we used:

```sql
NTILE(3) OVER (ORDER BY LASTDATE DESC)
```

### Result:

* `active`
* `inactive`
* `stale`

👉 Ensures balanced distribution even on compressed datasets

---

# 🧪 Data Quality Testing

We implemented a **multi-level testing strategy**.

---

## ✅ Schema Tests

* Primary keys → `unique`, `not_null`
* Controlled values → `accepted_values`
* Critical fields → `not_null`

---

## ✅ Data Quality Tests

* No negative values
* Valid date ranges
* Clean text fields
* Consistent calculations

---

## ✅ Business Logic Tests

### Tickets

* `solved_at >= created_at`
* Non-negative durations

### Hardware

* CPU cores > 0
* RAM consistency
* OS classification validity

### Drives

* Usage ratio between 0–1
* Storage consistency
* Risk level correctness

---

## ⚠️ Important Principle

Not all anomalies are errors.

Example:

* Duplicate devices in OCS → **expected**
* Marked as `WARN`, not `FAIL`

---

# ⚠️ Issues & Solutions

| Issue                       | Cause             | Solution          |
| --------------------------- | ----------------- | ----------------- |
| Duplicate IDs               | Multi-year data   | Composite PK      |
| Invalid dates               | Dirty data        | Nullification     |
| MySQL errors (`0000-00-00`) | Bad datetime      | Safe handling     |
| Duplicate devices           | Multiple scans    | Handled later     |
| OS inconsistencies          | Multilingual data | Flexible matching |

---

# ⚙️ Materialization Strategy

All staging models are:

```
materialized = view
```

### Why?

* Always up-to-date
* No storage overhead
* Lightweight
* Not intended for direct BI

---

# 🧠 Design Principles

### ❌ Avoid:

* Aggregations
* KPIs
* Filtering

### ✅ Focus on:

* Atomic data
* Consistency
* Reusability
* Early validation

---

# 🧩 Output

The staging layer produces:

* Clean GLPI datasets (tickets, users, logs…)
* Clean OCS datasets (hardware, drives, BIOS…)
* Unified structure across years
* Feature-ready data

---

# 🚀 Next Steps

```
stg_*
   ↓
int_* (feature engineering)
   ↓
dim_devices / fct_tickets
   ↓
ML models
```

---

# 💡 Final Insight

The staging layer is not just preprocessing.

> It is where **data trust is established**.

A strong staging layer guarantees:

* Reliable analytics
* Accurate dashboards
* Trustworthy AI models