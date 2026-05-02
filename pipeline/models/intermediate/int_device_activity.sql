WITH hardware AS (

    SELECT *
    FROM {{ ref('stg_ocs_hardware') }}

),

-- Deduplicate: keep latest record per device
ranked AS (

    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY hardware_id
            ORDER BY last_seen_at DESC
        ) AS rn
    FROM hardware

),

deduplicated AS (

    SELECT *
    FROM ranked
    WHERE rn = 1

),

max_date AS (
    SELECT MAX(last_seen_at) AS max_seen
    FROM deduplicated
),

final AS (

    SELECT
        d.hardware_id,

        d.last_seen_at,
        d.last_inventory_at,

        -- Days since last seen
        DATEDIFF(m.max_seen, d.last_seen_at) AS days_since_last_seen,

        -- Recompute status (DON'T trust staging blindly)
        CASE 
            WHEN DATEDIFF(m.max_seen, d.last_seen_at) <= 7 THEN 'active'
            WHEN DATEDIFF(m.max_seen, d.last_seen_at) <= 30 THEN 'inactive'
            ELSE 'stale'
        END AS device_status,

        -- Activity score
        CASE 
            WHEN DATEDIFF(m.max_seen, d.last_seen_at) <= 2 THEN 3
            WHEN DATEDIFF(m.max_seen, d.last_seen_at) <= 7 THEN 2
            ELSE 1
        END AS activity_score,

        -- Active flag
        CASE 
            WHEN DATEDIFF(m.max_seen, d.last_seen_at) <= 7 THEN 1
            ELSE 0
        END AS is_active_flag,

        d.source_year

    FROM deduplicated d
    CROSS JOIN max_date m

)

SELECT * FROM final