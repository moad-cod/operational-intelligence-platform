WITH drives AS (

    SELECT *
    FROM {{ ref('stg_ocs_drives') }}

),

filtered AS (

    -- Keep only real disks and remove noise
    SELECT *
    FROM drives
    WHERE drive_type = 'disk'
      AND is_tiny_partition = 0

),

aggregated AS (

    SELECT
        hardware_id,

        -- Total storage
        SUM(total_gb) AS total_storage_gb,

        -- Usage metrics
        AVG(usage_ratio) AS avg_usage_ratio,
        MAX(usage_ratio) AS max_usage_ratio,

        -- Disk count
        COUNT(*) AS disk_count,

        -- Critical flag (real risk)
        CASE 
            WHEN MAX(usage_ratio) >= 0.9 THEN 1
            ELSE 0
        END AS critical_disk_flag,

        -- Risk score from staging
        MAX(
            CASE 
                WHEN disk_risk_level = 'high' THEN 3
                WHEN disk_risk_level = 'medium' THEN 2
                WHEN disk_risk_level = 'low' THEN 1
                ELSE 0
            END
        ) AS max_disk_risk_score

    FROM filtered
    GROUP BY hardware_id

),

final AS (

    SELECT
        hardware_id,
        total_storage_gb,
        avg_usage_ratio,
        max_usage_ratio,
        disk_count,
        critical_disk_flag,
        max_disk_risk_score,

        -- FIXED LOGIC (priority to real usage risk)
        CASE 
            WHEN critical_disk_flag = 1 THEN 'high'
            WHEN max_disk_risk_score = 3 THEN 'high'
            WHEN max_disk_risk_score = 2 THEN 'medium'
            WHEN max_disk_risk_score = 1 THEN 'low'
            ELSE 'unknown'
        END AS storage_risk_level,

        -- Optional (advanced feature)
        CASE 
            WHEN avg_usage_ratio >= 0.7 THEN 'high'
            WHEN avg_usage_ratio >= 0.4 THEN 'medium'
            ELSE 'low'
        END AS usage_pressure

    FROM aggregated

)

SELECT * FROM final