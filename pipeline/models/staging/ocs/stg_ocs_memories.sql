WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_ocs_memories') }}

),

base AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', ID) AS memory_pk,

        ID AS memory_id,

        HARDWARE_ID AS hardware_id,

        -- =====================================
        -- MEMORY LABELS
        -- =====================================

        NULLIF(TRIM(CAPTION), '') AS memory_caption,

        NULLIF(TRIM(DESCRIPTION), '') AS memory_description,

        -- =====================================
        -- MEMORY CAPACITY
        -- =====================================

        CASE

            WHEN CAPACITY IS NULL THEN NULL

            WHEN TRIM(CAPACITY) = '' THEN NULL

            WHEN CAST(CAPACITY AS UNSIGNED) = 0
                 THEN NULL

            -- Bytes
            WHEN CAST(CAPACITY AS UNSIGNED) > 1000000000
                 THEN ROUND(
                    CAST(CAPACITY AS UNSIGNED)
                    / 1024 / 1024 / 1024,
                    2
                 )

            -- MB
            WHEN CAST(CAPACITY AS UNSIGNED) > 256
                 THEN ROUND(
                    CAST(CAPACITY AS UNSIGNED)
                    / 1024,
                    2
                 )

            ELSE NULL

        END AS capacity_gb,

        -- =====================================
        -- MEMORY PURPOSE
        -- =====================================

        NULLIF(TRIM(PURPOSE), '') AS memory_purpose,

        -- =====================================
        -- MEMORY TYPE
        -- =====================================

        CASE

            WHEN LOWER(TYPE) LIKE '%ddr5%'
                 THEN 'DDR5'

            WHEN LOWER(TYPE) LIKE '%ddr4%'
                 THEN 'DDR4'

            WHEN LOWER(TYPE) LIKE '%ddr3%'
                 THEN 'DDR3'

            WHEN LOWER(TYPE) LIKE '%ddr2%'
                 THEN 'DDR2'

            WHEN LOWER(TYPE) LIKE '%ddr%'
                 THEN 'DDR'

            WHEN LOWER(TYPE) LIKE '%sdram%'
                 THEN 'SDRAM'

            ELSE 'Other'

        END AS memory_type,

        -- =====================================
        -- MEMORY SPEED
        -- =====================================

        CASE

            WHEN SPEED IS NULL THEN NULL

            WHEN TRIM(SPEED) = '' THEN NULL

            WHEN CAST(SPEED AS UNSIGNED) = 0
                 THEN NULL

            ELSE CAST(SPEED AS UNSIGNED)

        END AS speed_mhz,

        -- =====================================
        -- PERFORMANCE
        -- =====================================

        CASE

            WHEN CAST(SPEED AS UNSIGNED) >= 3200
                 THEN 'high'

            WHEN CAST(SPEED AS UNSIGNED) >= 1600
                 THEN 'medium'

            WHEN CAST(SPEED AS UNSIGNED) > 0
                 THEN 'low'

            ELSE 'unknown'

        END AS performance_tier,

        -- =====================================
        -- SLOT INFORMATION
        -- =====================================

        CASE

            WHEN NUMSLOTS <= 0 THEN NULL

            ELSE NUMSLOTS

        END AS num_slots,

        -- =====================================
        -- SERIAL NUMBER
        -- =====================================

        CASE

            WHEN SERIALNUMBER IS NULL THEN NULL

            WHEN TRIM(SERIALNUMBER) = '' THEN NULL

            WHEN LOWER(TRIM(SERIALNUMBER)) IN (
                '00000000',
                'sernum',
                'none'
            ) THEN NULL

            ELSE TRIM(SERIALNUMBER)

        END AS serial_number,

        -- =====================================
        -- QUALITY FLAGS
        -- =====================================

        CASE

            WHEN SERIALNUMBER IS NULL THEN FALSE

            WHEN TRIM(SERIALNUMBER) = '' THEN FALSE

            ELSE TRUE

        END AS has_serial_number,

        CASE

            WHEN CAPACITY IS NULL THEN FALSE

            ELSE TRUE

        END AS has_capacity,

        source_year,

        source_system

    FROM source

),

final AS (

    SELECT

        *,

        -- =====================================
        -- MEMORY SIZE TIER
        -- =====================================

        CASE

            WHEN capacity_gb >= 16
                 THEN 'high'

            WHEN capacity_gb >= 8
                 THEN 'medium'

            WHEN capacity_gb > 0
                 THEN 'low'

            ELSE 'unknown'

        END AS memory_size_tier

    FROM base

)

SELECT *

FROM final