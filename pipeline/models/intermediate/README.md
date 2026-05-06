🧱 Intermediate Layer — Feature Engineering (Silver Layer)

The Intermediate (Silver) layer transforms clean, standardized data into meaningful, business-ready features.

![Alt Text](/pipeline/models/intermediate/DAG.png)
It acts as a bridge between:

🧼 Staging Layer → cleaned & standardized data
🏆 Gold Layer → analytics, BI, and ML-ready models
📂 Project Structure
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
🎯 Purpose

This layer converts raw data into usable signals:

✔ Feature engineering
✔ Aggregations
✔ Business logic
✔ Signal extraction
✔ ML-ready dataset preparation
🔥 Models Overview
🧠 Device Activity — int_device_activity.sql
Source: stg_ocs_hardware
Goal: Measure device usage and activity

Features

last_seen_at
activity_score
is_active_flag
device_status

Logic

CASE 
    WHEN last_seen_at >= DATE_SUB(max_date, INTERVAL 7 DAY) THEN 'active'
    WHEN last_seen_at >= DATE_SUB(max_date, INTERVAL 30 DAY) THEN 'inactive'
    ELSE 'stale'
END
💾 Device Storage — int_device_storage.sql
Source: stg_ocs_drives
Goal: Detect storage risks

Features

total_storage_gb
avg_usage_ratio
max_usage_ratio
disk_count
critical_disk_flag

Rule

usage_ratio > 0.9 → critical
⚙️ Device Performance — int_device_performance.sql
Sources
stg_glpi_deviceprocessors
stg_glpi_devicememories
stg_glpi_devicegraphiccards
Goal: Evaluate hardware performance

Output

component_type | performance_score | performance_tier

Scoring

CPU → performance tier
Memory → size (GB)
GPU → VRAM + type

⚠️ Design Choice

GLPI and OCS are not directly linked:

GLPI → components
OCS → devices

👉 Performance is modeled at component level (no forced joins)

🎫 Ticket Features — int_ticket_features.sql
Sources
stg_glpi_tickets
stg_glpi_ticketfollowups
Goal: Extract behavioral signals

Features

followup_count
duration_days
positive_signals
negative_signals
is_resolved_flag

Logic

LOWER(content) LIKE '%resolved%'
LOWER(content) LIKE '%error%'
🧪 Data Quality
✅ Schema Tests
not_null
accepted_values
unique
✅ Business Tests
performance_score BETWEEN 0 AND 3
Invalid tier combinations
usage_ratio > 1
⚠️ Key Design Decisions
1. GLPI vs OCS Separation
No direct mapping

👉 Solution:

Keep models separate
Merge in Gold layer
2. Avoid Cartesian Explosion
CPU × RAM × GPU ❌

👉 Use:

Component-level modeling ✅
3. Real-World Data Handling
Low RAM distribution → adjusted thresholds
Missing GPU VRAM → handled safely
Null values → defaults applied
⚙️ Materialization
materialized: view

Why

Lightweight
Always up-to-date
No storage overhead
Fast iteration
🧠 Design Principles

Not included

❌ Data cleaning (Staging)
❌ Business KPIs (Gold)

Included

✔ Feature engineering
✔ Aggregations
✔ Signal extraction
✔ Consistent transformations
🚀 What This Enables
🏆 Gold Layer
dim_devices
fct_tickets
device_health_score
🤖 Machine Learning
Risk prediction
Failure detection
Ticket escalation
📊 BI & Dashboards
Device performance
Storage monitoring
Ticket analytics
🎯 Final Insight
Staging      = clean data  
Intermediate = smart data  
Gold         = business data  

👉 This is the layer where data becomes valuable.