WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_ocs_bios') }}

),

base AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', HARDWARE_ID) AS bios_pk,

        HARDWARE_ID AS hardware_id,

        -- =====================================
        -- SYSTEM INFORMATION
        -- =====================================

        NULLIF(TRIM(SMANUFACTURER), '') AS system_manufacturer,

        NULLIF(TRIM(SMODEL), '') AS system_model,

        -- =====================================
        -- SERIAL CLEANING
        -- =====================================

        CASE

            WHEN SSN IS NULL THEN NULL

            WHEN TRIM(SSN) = '' THEN NULL

            WHEN LOWER(TRIM(SSN)) IN (
                'oem_serial',
                'system serial number',
                '12345678'
            ) THEN NULL

            ELSE TRIM(SSN)

        END AS serial_number,

        -- =====================================
        -- DEVICE TYPE
        -- =====================================

        CASE

            WHEN LOWER(TYPE) LIKE '%desktop%'
                 THEN 'desktop'

            WHEN LOWER(TYPE) LIKE '%notebook%'
                 THEN 'laptop'

            WHEN LOWER(TYPE) LIKE '%portable%'
                 THEN 'laptop'

            WHEN LOWER(TYPE) LIKE '%optiplex%'
                 THEN 'desktop'

            WHEN LOWER(TYPE) LIKE '%tower%'
                 THEN 'desktop'

            WHEN LOWER(TYPE) LIKE '%mini%'
                 THEN 'desktop'

            WHEN LOWER(TYPE) LIKE '%laptop%'
                 THEN 'laptop'

            WHEN LOWER(TYPE) LIKE '%server%'
                 THEN 'server'

            ELSE 'other'

        END AS device_type,

        -- =====================================
        -- BIOS INFORMATION
        -- =====================================

        NULLIF(TRIM(BMANUFACTURER), '') AS bios_manufacturer,

        CASE

            WHEN BVERSION IS NULL THEN NULL

            WHEN TRIM(BVERSION) = '' THEN NULL

            WHEN BVERSION LIKE '%;%'
                 THEN TRIM(SUBSTRING_INDEX(BVERSION, ';', 1))

            ELSE TRIM(BVERSION)

        END AS bios_version,

        -- =====================================
        -- BIOS DATE
        -- =====================================

        CASE

            WHEN BDATE IS NULL THEN NULL

            WHEN TRIM(BDATE) = '' THEN NULL

            WHEN STR_TO_DATE(BDATE, '%d/%m/%Y') IS NOT NULL
                 THEN STR_TO_DATE(BDATE, '%d/%m/%Y')

            WHEN STR_TO_DATE(BDATE, '%m/%d/%Y') IS NOT NULL
                 THEN STR_TO_DATE(BDATE, '%m/%d/%Y')

            WHEN STR_TO_DATE(BDATE, '%Y-%m-%d') IS NOT NULL
                 THEN STR_TO_DATE(BDATE, '%Y-%m-%d')

            ELSE NULL

        END AS bios_date,

        -- =====================================
        -- ASSET TAG
        -- =====================================

        CASE

            WHEN ASSETTAG IS NULL THEN NULL

            WHEN TRIM(ASSETTAG) = '' THEN NULL

            WHEN LOWER(ASSETTAG) LIKE '%no asset%'
                 THEN NULL

            WHEN LOWER(ASSETTAG) LIKE '%o.e.m%'
                 THEN NULL

            ELSE TRIM(ASSETTAG)

        END AS asset_tag,

        -- =====================================
        -- MANUFACTURER GROUP
        -- =====================================

        CASE

            WHEN LOWER(SMANUFACTURER) LIKE '%hewlett%'
                 THEN 'HP'

            WHEN LOWER(SMANUFACTURER) LIKE '%compaq%'
                 THEN 'HP'

            WHEN LOWER(SMANUFACTURER) LIKE '%dell%'
                 THEN 'Dell'

            WHEN LOWER(SMANUFACTURER) LIKE '%lenovo%'
                 THEN 'Lenovo'

            WHEN LOWER(SMANUFACTURER) LIKE '%foxconn%'
                 THEN 'Foxconn'

            WHEN LOWER(SMANUFACTURER) LIKE '%micro-star%'
                 THEN 'MSI'

            ELSE 'Other'

        END AS manufacturer_group,

        -- =====================================
        -- QUALITY FLAGS
        -- =====================================

        CASE

            WHEN SSN IS NULL THEN FALSE

            ELSE TRUE

        END AS has_serial_number,

        CASE

            WHEN BVERSION IS NULL THEN FALSE

            ELSE TRUE

        END AS has_bios_version,

        -- =====================================
        -- SOURCE METADATA
        -- =====================================

        source_year,

        source_system

    FROM source

),

final AS (

    SELECT

        *,

        CASE

            WHEN bios_date IS NULL THEN NULL

            ELSE TIMESTAMPDIFF(
                YEAR,
                bios_date,
                CURRENT_DATE
            )

        END AS bios_age_years,

        CASE

            WHEN bios_date IS NULL
                 THEN 'unknown'

            WHEN TIMESTAMPDIFF(
                YEAR,
                bios_date,
                CURRENT_DATE
            ) >= 10
                 THEN 'critical'

            WHEN TIMESTAMPDIFF(
                YEAR,
                bios_date,
                CURRENT_DATE
            ) >= 5
                 THEN 'high'

            WHEN TIMESTAMPDIFF(
                YEAR,
                bios_date,
                CURRENT_DATE
            ) >= 2
                 THEN 'medium'

            ELSE 'low'

        END AS bios_risk_level

    FROM base

)

SELECT *

FROM final