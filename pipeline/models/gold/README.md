models/gold/

├── dimensions/
│   ├── dim_devices.sql
│   ├── dim_users.sql
│   └── dim_components.sql
│
├── facts/
│   ├── fct_tickets.sql
│   ├── fct_storage_usage.sql
│   └── fct_device_activity.sql
│
├── marts/
│   ├── mart_device_health.sql
│   ├── mart_ticket_performance.sql
│   └── mart_risk_overview.sql
│
└── schema.yml

git commit -m "test(gold): add data quality and logic tests for {table name} table"