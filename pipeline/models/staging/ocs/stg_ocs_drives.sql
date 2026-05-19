WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_ocs_drives') }}

),

cleaned AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', ID) AS drive_pk,

        -- =====================================
        -- BUSINESS KEYS
        -- =====================================

        ID AS drive_id,

        HARDWARE_ID AS hardware_id,

        -- =====================================
        -- DRIVE LETTER
        -- =====================================

        CASE

            WHEN LETTER IS NULL THEN NULL

            WHEN TRIM(LETTER) = '' THEN NULL

            ELSE UPPER(TRIM(LETTER))

        END AS drive_letter,

        -- =====================================
        -- DRIVE TYPE
        -- =====================================

        CASE

            WHEN LOWER(TYPE) LIKE '%fixed%'
                 THEN 'fixed'

            WHEN LOWER(TYPE) LIKE '%local%'
                 THEN 'fixed'

            WHEN LOWER(TYPE) LIKE '%removable%'
                 THEN 'removable'

            WHEN LOWER(TYPE) LIKE '%usb%'
                 THEN 'usb'

            WHEN LOWER(TYPE) LIKE '%network%'
                 THEN 'network'

            WHEN LOWER(TYPE) LIKE '%cd%'
                 THEN 'cdrom'

            WHEN LOWER(TYPE) LIKE '%dvd%'
                 THEN 'cdrom'

            ELSE 'other'

        END AS drive_type,

        -- =====================================
        -- FILESYSTEM
        -- =====================================

        CASE

            WHEN FILESYSTEM IS NULL THEN NULL

            WHEN TRIM(FILESYSTEM) = '' THEN NULL

            ELSE UPPER(TRIM(FILESYSTEM))

        END AS filesystem,

        -- =====================================
        -- STORAGE CONVERSION
        -- =====================================

        CASE

            WHEN TOTAL IS NULL THEN NULL

            WHEN TOTAL <= 0 THEN NULL

            ELSE ROUND(TOTAL / 1024, 2)

        END AS total_size_gb,

        CASE

            WHEN FREE IS NULL THEN NULL

            WHEN FREE < 0 THEN NULL

            ELSE ROUND(FREE / 1024, 2)

        END AS free_size_gb,

        -- =====================================
        -- FILE COUNT
        -- =====================================

        CASE

            WHEN NUMFILES < 0 THEN NULL

            ELSE NUMFILES

        END AS num_files,

        -- =====================================
        -- VOLUME LABEL
        -- =====================================

        NULLIF(TRIM(VOLUMN), '') AS volume_label,

        -- =====================================
        -- DATE
        -- =====================================

        CREATEDATE AS created_date,

        -- =====================================
        -- STORAGE UTILIZATION
        -- =====================================

        CASE

            WHEN TOTAL IS NULL THEN NULL

            WHEN TOTAL <= 0 THEN NULL

            WHEN FREE IS NULL THEN NULL

            ELSE ROUND(
                ((TOTAL - FREE) / TOTAL) * 100,
                2
            )

        END AS used_percent,

        -- =====================================
        -- STORAGE STATUS
        -- =====================================

        CASE

            WHEN TOTAL IS NULL THEN 'unknown'

            WHEN TOTAL <= 0 THEN 'unknown'

            WHEN FREE IS NULL THEN 'unknown'

            WHEN ((TOTAL - FREE) / TOTAL) >= 0.90
                 THEN 'critical'

            WHEN ((TOTAL - FREE) / TOTAL) >= 0.75
                 THEN 'high'

            WHEN ((TOTAL - FREE) / TOTAL) >= 0.50
                 THEN 'medium'

            ELSE 'healthy'

        END AS storage_health,

        -- =====================================
        -- LARGE DRIVE FLAG
        -- =====================================

        CASE

            WHEN TOTAL >= 500000 THEN TRUE

            ELSE FALSE

        END AS is_large_drive,

        -- =====================================
        -- SOURCE METADATA
        -- =====================================

        source_year,

        source_system

    FROM source

)

SELECT *

FROM cleaned