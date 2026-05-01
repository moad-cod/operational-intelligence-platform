WITH source AS (

    SELECT *
    FROM {{ ref('base_ocs_drives') }}

),

cleaned AS (

    SELECT
        -- Composite PK
        CONCAT(year, '_', ID) AS drive_pk,

        -- Keys
        ID AS drive_id,
        HARDWARE_ID AS hardware_id,

        -- Normalize drive letter
        REPLACE(TRIM(LETTER), '/', '') AS drive_letter,

        -- Normalize drive type
        CASE 
            WHEN TYPE LIKE '%Hard%' THEN 'disk'
            WHEN TYPE LIKE '%CD%' THEN 'cdrom'
            WHEN TYPE LIKE '%Removable%' THEN 'removable'
            ELSE 'other'
        END AS drive_type,

        -- Filesystem
        CASE 
            WHEN FILESYSTEM IS NULL OR TRIM(FILESYSTEM) = '' THEN NULL
            ELSE UPPER(TRIM(FILESYSTEM))
        END AS filesystem,

        -- Storage (MB → GB)
        CASE 
            WHEN TOTAL IS NULL OR TOTAL = 0 THEN NULL
            ELSE ROUND(TOTAL / 1024, 2)
        END AS total_gb,

        CASE 
            WHEN TOTAL IS NULL OR TOTAL = 0 THEN NULL
            WHEN FREE IS NULL THEN NULL
            ELSE ROUND(FREE / 1024, 2)
        END AS free_gb,

        CASE 
            WHEN TOTAL > 0 AND FREE IS NOT NULL 
                THEN ROUND((TOTAL - FREE) / 1024, 2)
            ELSE NULL
        END AS used_gb,

        CASE 
            WHEN TOTAL > 0 AND FREE IS NOT NULL 
                THEN ROUND((TOTAL - FREE) / TOTAL, 3)
            ELSE NULL
        END AS usage_ratio,

        -- Volume label clean
        CASE 
            WHEN VOLUMN IS NULL THEN NULL
            WHEN TRIM(VOLUMN) = '' THEN NULL
            ELSE TRIM(VOLUMN)
        END AS volume_label,

        -- Improved partition classification
        CASE 
            -- FIRST: drive letter rule (strongest signal)
            WHEN REPLACE(TRIM(LETTER), '/', '') = 'C:' THEN 'system'

            -- THEN label-based detection
            WHEN LOWER(VOLUMN) LIKE '%system%' THEN 'system'
            WHEN LOWER(VOLUMN) LIKE '%os%' THEN 'system'
            WHEN LOWER(VOLUMN) LIKE '%win%' THEN 'system'

            WHEN LOWER(VOLUMN) LIKE '%data%' THEN 'data'
            WHEN LOWER(VOLUMN) LIKE '%donne%' THEN 'data'

            WHEN LOWER(VOLUMN) LIKE '%recovery%' THEN 'recovery'
            WHEN LOWER(VOLUMN) LIKE '%recuper%' THEN 'recovery'

            ELSE 'other'
        END AS partition_type,

        -- Disk risk level (VERY IMPORTANT)
        CASE 
            WHEN TOTAL > 0 AND FREE IS NOT NULL AND (TOTAL - FREE)/TOTAL >= 0.9 THEN 'critical'
            WHEN TOTAL > 0 AND FREE IS NOT NULL AND (TOTAL - FREE)/TOTAL >= 0.75 THEN 'high'
            WHEN TOTAL > 0 AND FREE IS NOT NULL AND (TOTAL - FREE)/TOTAL >= 0.5 THEN 'medium'
            WHEN TOTAL > 0 AND FREE IS NOT NULL THEN 'low'
            ELSE NULL
        END AS disk_risk_level,

        -- Tiny partition flag
        CASE 
            WHEN TOTAL > 0 AND (TOTAL / 1024) < 1 THEN 1
            ELSE 0
        END AS is_tiny_partition,

        -- Metadata
        year AS source_year

    FROM source

)

SELECT *
FROM cleaned