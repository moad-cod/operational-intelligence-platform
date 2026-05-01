WITH source AS (

    SELECT *
    FROM {{ ref('base_glpi_devicememories') }}

),

base AS (

    SELECT
        -- Composite PK
        CONCAT(year, '_', id) AS memory_pk,

        -- Keys
        id AS memory_id,

        -- Raw text
        designation,

        -- Memory type extraction
        CASE 
            WHEN designation LIKE '%DDR3%' THEN 'DDR3'
            WHEN designation LIKE '%DDR2%' THEN 'DDR2'
            WHEN designation LIKE '%DDR%' THEN 'DDR'
            WHEN designation LIKE '%SDRAM%' THEN 'SDRAM'
            WHEN designation LIKE '%RDRAM%' THEN 'RDRAM'
            WHEN designation LIKE '%FLASH%' THEN 'FLASH'
            ELSE 'Other'
        END AS memory_type,

        --  FIXED ECC detection (IMPORTANT)
        CASE 
            WHEN designation LIKE '%No ECC%' THEN 0
            WHEN designation LIKE '%ECC%' THEN 1
            ELSE 0
        END AS is_ecc,

        --  Clean frequency
        CASE 
            WHEN frequence IS NULL THEN NULL
            WHEN frequence = '0' THEN NULL
            WHEN CAST(frequence AS UNSIGNED) > 5000 THEN NULL
            ELSE CAST(frequence AS UNSIGNED)
        END AS frequency_mhz,

        --  Convert size (MB → GB)
        CASE 
            WHEN specif_default IS NULL THEN NULL
            WHEN specif_default = 0 THEN NULL
            ELSE specif_default / 1024
        END AS memory_size_gb,

        -- Metadata
        year AS source_year

    FROM source

),

cleaned AS (

    SELECT
        *,

        --  Performance tier (based on type + frequency)
        CASE 
            WHEN memory_type = 'DDR3' AND frequency_mhz >= 1333 THEN 'high'
            WHEN memory_type = 'DDR3' THEN 'medium'
            WHEN memory_type = 'DDR2' THEN 'low'
            WHEN memory_type = 'DDR' THEN 'low'
            ELSE 'unknown'
        END AS performance_tier

    FROM base

)

SELECT * FROM cleaned