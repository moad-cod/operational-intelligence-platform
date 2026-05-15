WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_glpi_devicememories') }}

),

base AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', id) AS memory_pk,

        -- =====================================
        -- IDENTIFIERS
        -- =====================================

        id AS memory_id,

        designation,

        -- =====================================
        -- MEMORY TYPE
        -- =====================================

        CASE

            WHEN designation LIKE '%DDR5%' THEN 'DDR5'

            WHEN designation LIKE '%DDR4%' THEN 'DDR4'

            WHEN designation LIKE '%DDR3%' THEN 'DDR3'

            WHEN designation LIKE '%DDR2%' THEN 'DDR2'

            WHEN designation LIKE '%DDR%' THEN 'DDR'

            WHEN designation LIKE '%SDRAM%' THEN 'SDRAM'

            WHEN designation LIKE '%RDRAM%' THEN 'RDRAM'

            WHEN designation LIKE '%FLASH%' THEN 'FLASH'

            ELSE 'Other'

        END AS memory_type,

        -- =====================================
        -- ECC DETECTION
        -- =====================================

        CASE

            WHEN designation LIKE '%No ECC%' THEN FALSE

            WHEN designation LIKE '%ECC%' THEN TRUE

            ELSE FALSE

        END AS is_ecc,

        -- =====================================
        -- FREQUENCY CLEANING
        -- =====================================

        CASE

            WHEN frequence IS NULL THEN NULL

            WHEN frequence = '0' THEN NULL

            WHEN CAST(frequence AS UNSIGNED) > 5000 THEN NULL

            ELSE CAST(frequence AS UNSIGNED)

        END AS frequency_mhz,

        -- =====================================
        -- FREQUENCY QUALITY FLAG
        -- =====================================

        CASE

            WHEN frequence IS NULL THEN FALSE

            WHEN frequence = '0' THEN FALSE

            ELSE TRUE

        END AS has_frequency_data,

        -- =====================================
        -- MEMORY SIZE NORMALIZATION
        -- =====================================

        ROUND(

            CASE

                WHEN specif_default IS NULL THEN NULL

                WHEN specif_default = 0 THEN NULL

                ELSE specif_default / 1024

            END,

            2

        ) AS memory_size_gb,

        -- =====================================
        -- METADATA
        -- =====================================

        source_year,

        source_system

    FROM source

),

filtered AS (

    SELECT *

    FROM base

    WHERE memory_type != 'FLASH'

),

cleaned AS (

    SELECT

        *,

        -- =====================================
        -- MEMORY CAPACITY TIER
        -- =====================================

        CASE

            WHEN memory_size_gb >= 16 THEN 'enterprise'

            WHEN memory_size_gb >= 8 THEN 'high'

            WHEN memory_size_gb >= 4 THEN 'medium'

            WHEN memory_size_gb >= 1 THEN 'low'

            ELSE 'legacy'

        END AS memory_capacity_tier,

        -- =====================================
        -- PERFORMANCE TIER
        -- =====================================

        CASE

            WHEN memory_type IN ('DDR5', 'DDR4')
                 THEN 'high'

            WHEN memory_type = 'DDR3'
                 AND frequency_mhz >= 1333
                 THEN 'high'

            WHEN memory_type = 'DDR3'
                 AND frequency_mhz IS NOT NULL
                 THEN 'medium'

            WHEN memory_type = 'DDR3'
                 THEN 'unknown'

            WHEN memory_type IN (
                'DDR2',
                'DDR',
                'SDRAM',
                'RDRAM'
            ) THEN 'low'

            ELSE 'unknown'

        END AS performance_tier,

        -- =====================================
        -- SERVER MEMORY FLAG
        -- =====================================

        CASE

            WHEN is_ecc = TRUE THEN TRUE

            ELSE FALSE

        END AS is_server_memory

    FROM filtered

)

SELECT *

FROM cleaned