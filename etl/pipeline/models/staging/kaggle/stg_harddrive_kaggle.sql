WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'raw_harddrive_data') }}

),

cleaned AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        MD5(
            CONCAT(
                IFNULL(serial_number, ''),
                '_',
                IFNULL(date, '')
            )
        ) AS harddrive_pk,

        -- =====================================
        -- IDENTIFICATION
        -- =====================================

        NULLIF(TRIM(serial_number), '') AS serial_number,

        NULLIF(TRIM(model), '') AS model_name,

        -- =====================================
        -- DATE
        -- =====================================

        CASE
            WHEN date IS NULL THEN NULL
            WHEN TRIM(date) = '' THEN NULL
            ELSE date
        END AS snapshot_date,

        -- =====================================
        -- CAPACITY
        -- =====================================

        CASE
            WHEN capacity_bytes IS NULL THEN NULL
            WHEN capacity_bytes <= 0 THEN NULL
            ELSE ROUND(
                capacity_bytes / 1024 / 1024 / 1024,
                2
            )
        END AS capacity_gb,

        -- =====================================
        -- FAILURE FLAG
        -- =====================================

        CASE
            WHEN failure = 1 THEN TRUE
            ELSE FALSE
        END AS has_failed,

        -- =====================================
        -- SMART METRICS
        -- =====================================

        smart_5_raw AS reallocated_sectors,

        smart_9_raw AS power_on_hours,

        smart_187_raw AS reported_uncorrectable_errors,

        smart_188_raw AS command_timeout,

        smart_197_raw AS current_pending_sector_count,

        smart_198_raw AS offline_uncorrectable,

        smart_199_raw AS udma_crc_errors,

        smart_194_raw AS temperature_celsius,

        -- =====================================
        -- HEALTH FLAGS
        -- =====================================

        CASE
            WHEN smart_5_raw > 0
                 THEN TRUE
            ELSE FALSE
        END AS has_reallocated_sectors,

        CASE
            WHEN smart_197_raw > 0
                 THEN TRUE
            ELSE FALSE
        END AS has_pending_sectors,

        CASE
            WHEN smart_198_raw > 0
                 THEN TRUE
            ELSE FALSE
        END AS has_uncorrectable_sectors,

        CASE
            WHEN smart_199_raw > 0
                 THEN TRUE
            ELSE FALSE
        END AS has_crc_errors,

        -- =====================================
        -- HEALTH SCORE
        -- =====================================

        CASE

            WHEN failure = 1
                 THEN 'failed'

            WHEN smart_197_raw > 0
                 OR smart_198_raw > 0
                 THEN 'critical'

            WHEN smart_5_raw > 0
                 THEN 'warning'

            ELSE 'healthy'

        END AS health_status,

        -- =====================================
        -- RISK SCORE
        -- =====================================

        CASE

            WHEN failure = 1 THEN 100

            ELSE
                (
                    IFNULL(smart_5_raw, 0)
                    +
                    IFNULL(smart_197_raw, 0)
                    +
                    IFNULL(smart_198_raw, 0)
                )

        END AS disk_risk_score

    FROM source

)

SELECT DISTINCT *

FROM cleaned