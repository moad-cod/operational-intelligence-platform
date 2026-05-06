WITH activity AS (

    SELECT
        hardware_id,

        last_seen_at,
        last_inventory_at,
        days_since_last_seen,

        device_status,
        activity_score,
        is_active_flag,

        source_year

    FROM {{ ref('int_device_activity') }}

),

storage AS (

    SELECT
        hardware_id,

        total_storage_gb,
        avg_usage_ratio,
        max_usage_ratio,

        disk_count,
        critical_disk_flag,
        max_disk_risk_score,

        storage_risk_level,
        usage_pressure

    FROM {{ ref('int_device_storage') }}

),

final AS (

    SELECT
        a.hardware_id AS device_id,

        -- Activity metrics
        a.last_seen_at,
        a.last_inventory_at,
        a.days_since_last_seen,

        a.device_status,
        a.activity_score,
        a.is_active_flag,

        -- Storage metrics
        s.total_storage_gb,
        s.avg_usage_ratio,
        s.max_usage_ratio,

        s.disk_count,
        s.critical_disk_flag,
        s.max_disk_risk_score,

        s.storage_risk_level,
        s.usage_pressure,

        -- Global business health indicator
        CASE
            WHEN a.device_status = 'stale' THEN 'critical'

            WHEN s.storage_risk_level = 'critical'
                 AND a.activity_score < 40 THEN 'high_risk'

            WHEN s.storage_risk_level IN ('high', 'critical') THEN 'warning'

            WHEN a.device_status = 'inactive' THEN 'monitor'

            ELSE 'healthy'
        END AS device_health_status,

        -- Operational priority
        CASE
            WHEN a.device_status = 'stale'
                 AND s.storage_risk_level = 'critical' THEN 'urgent'

            WHEN s.storage_risk_level = 'critical' THEN 'high'

            WHEN a.device_status = 'inactive' THEN 'medium'

            ELSE 'low'
        END AS operational_priority,

        a.source_year

    FROM activity a
    LEFT JOIN storage s
        ON a.hardware_id = s.hardware_id

)

SELECT * FROM final