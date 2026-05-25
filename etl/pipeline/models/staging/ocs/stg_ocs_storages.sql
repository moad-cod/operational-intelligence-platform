WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_ocs_storages') }}

),

base AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', ID) AS storage_pk,

        -- =====================================
        -- BUSINESS KEYS
        -- =====================================

        ID AS storage_id,

        HARDWARE_ID AS hardware_id,

        -- =====================================
        -- MANUFACTURER
        -- =====================================

        NULLIF(TRIM(MANUFACTURER), '') AS manufacturer,

        CASE

            WHEN LOWER(MANUFACTURER) LIKE '%seagate%'
                 THEN 'Seagate'

            WHEN LOWER(MANUFACTURER) LIKE '%western%'
                 OR LOWER(MANUFACTURER) LIKE '%wd%'
                 THEN 'Western Digital'

            WHEN LOWER(MANUFACTURER) LIKE '%samsung%'
                 THEN 'Samsung'

            WHEN LOWER(MANUFACTURER) LIKE '%toshiba%'
                 THEN 'Toshiba'

            WHEN LOWER(MANUFACTURER) LIKE '%kingston%'
                 THEN 'Kingston'

            WHEN LOWER(MANUFACTURER) LIKE '%intel%'
                 THEN 'Intel'

            ELSE 'Other'

        END AS manufacturer_group,

        -- =====================================
        -- STORAGE IDENTIFICATION
        -- =====================================

        NULLIF(TRIM(NAME), '') AS storage_name,

        NULLIF(TRIM(MODEL), '') AS storage_model,

        NULLIF(TRIM(DESCRIPTION), '') AS storage_description,

        -- =====================================
        -- STORAGE TYPE
        -- =====================================

        CASE

            -- =====================================
            -- NVME
            -- =====================================

            WHEN LOWER(CONCAT(
                IFNULL(NAME, ''),
                ' ',
                IFNULL(MODEL, ''),
                ' ',
                IFNULL(DESCRIPTION, ''),
                ' ',
                IFNULL(TYPE, '')
            )) LIKE '%nvme%'
                THEN 'NVMe'

            -- =====================================
            -- SSD
            -- =====================================

            WHEN LOWER(CONCAT(
                IFNULL(NAME, ''),
                ' ',
                IFNULL(MODEL, ''),
                ' ',
                IFNULL(DESCRIPTION, ''),
                ' ',
                IFNULL(TYPE, '')
            )) LIKE '%ssd%'
                THEN 'SSD'

            -- =====================================
            -- HDD
            -- =====================================

            WHEN LOWER(CONCAT(
                IFNULL(NAME, ''),
                ' ',
                IFNULL(MODEL, ''),
                ' ',
                IFNULL(DESCRIPTION, ''),
                ' ',
                IFNULL(TYPE, '')
            )) LIKE '%hard disk%'
                THEN 'HDD'

            WHEN LOWER(TYPE) LIKE '%ata%'
                THEN 'HDD'

            WHEN LOWER(TYPE) LIKE '%sata%'
                THEN 'HDD'

            WHEN LOWER(TYPE) LIKE '%scsi%'
                THEN 'HDD'

            ELSE 'Other'

        END AS storage_type,

        -- =====================================
        -- STORAGE CAPACITY
        -- =====================================

        CASE

            WHEN DISKSIZE IS NULL THEN NULL

            WHEN DISKSIZE <= 0 THEN NULL

            ELSE ROUND(
                DISKSIZE / 1024,
                2
            )

        END AS disk_size_gb,

        -- =====================================
        -- STORAGE SIZE TIER
        -- =====================================

        CASE

            WHEN DISKSIZE >= 1000000
                 THEN 'high'

            WHEN DISKSIZE >= 500000
                 THEN 'medium'

            WHEN DISKSIZE > 0
                 THEN 'low'

            ELSE 'unknown'

        END AS storage_size_tier,

        -- =====================================
        -- SERIAL NUMBER
        -- =====================================

        CASE

            WHEN SERIALNUMBER IS NULL THEN NULL

            WHEN TRIM(SERIALNUMBER) = '' THEN NULL

            WHEN LOWER(TRIM(SERIALNUMBER)) IN (
                '00000000',
                'none',
                'unknown'
            ) THEN NULL

            ELSE TRIM(SERIALNUMBER)

        END AS serial_number,

        -- =====================================
        -- FIRMWARE
        -- =====================================

        NULLIF(TRIM(FIRMWARE), '') AS firmware_version,

        -- =====================================
        -- QUALITY FLAGS
        -- =====================================

        CASE

            WHEN SERIALNUMBER IS NULL THEN FALSE

            WHEN TRIM(SERIALNUMBER) = '' THEN FALSE

            ELSE TRUE

        END AS has_serial_number,

        CASE

            WHEN FIRMWARE IS NULL THEN FALSE

            WHEN TRIM(FIRMWARE) = '' THEN FALSE

            ELSE TRUE

        END AS has_firmware,

        -- =====================================
        -- PERFORMANCE CATEGORY
        -- =====================================

        CASE

            WHEN LOWER(TYPE) LIKE '%nvme%'
                 THEN 'ultra'

            WHEN LOWER(TYPE) LIKE '%ssd%'
                 THEN 'high'

            WHEN LOWER(TYPE) LIKE '%sas%'
                 THEN 'medium'

            WHEN LOWER(TYPE) LIKE '%hdd%'
                 THEN 'low'

            ELSE 'unknown'

        END AS performance_tier,

        -- =====================================
        -- SOURCE METADATA
        -- =====================================

        source_year,

        source_system

    FROM source

)

SELECT *

FROM base