WITH source AS (

    SELECT *
    FROM {{ ref('base_ocs_bios') }}

),

base AS (

    SELECT
        -- Composite PK
        CONCAT(year, '_', HARDWARE_ID) AS bios_pk,

        -- Keys
        HARDWARE_ID AS hardware_id,

        -- System info
        TRIM(SMANUFACTURER) AS system_manufacturer,
        TRIM(SMODEL) AS system_model,

        -- Serial cleaning
        CASE 
            WHEN SSN IS NULL THEN NULL
            WHEN TRIM(SSN) = '' THEN NULL
            WHEN LOWER(SSN) IN ('oem_serial', 'system serial number', '12345678') THEN NULL
            ELSE TRIM(SSN)
        END AS serial_number,

        -- Device type
        CASE 
            WHEN TYPE LIKE '%Desktop%' THEN 'desktop'
            WHEN TYPE LIKE '%Notebook%' THEN 'laptop'
            WHEN TYPE LIKE '%Portable%' THEN 'laptop'
            WHEN TYPE LIKE '%OptiPlex%' THEN 'desktop'
            WHEN TYPE LIKE '%Tower%' THEN 'desktop'
            WHEN TYPE LIKE '%Mini%' THEN 'desktop'
            WHEN TYPE LIKE '%Laptop%' THEN 'laptop'
            ELSE 'other'
        END AS device_type,

        -- BIOS manufacturer
        TRIM(BMANUFACTURER) AS bios_manufacturer,

        -- Clean BIOS version
        CASE 
            WHEN BVERSION IS NULL THEN NULL
            WHEN TRIM(BVERSION) = '' THEN NULL
            WHEN BVERSION LIKE '%;%' 
                THEN TRIM(SUBSTRING_INDEX(BVERSION, ';', 1))
            ELSE TRIM(BVERSION)
        END AS bios_version,

        -- SAFE DATE PARSING
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

        -- Asset tag
        CASE 
            WHEN ASSETTAG IS NULL THEN NULL
            WHEN TRIM(ASSETTAG) = '' THEN NULL
            WHEN LOWER(ASSETTAG) LIKE '%no asset%' THEN NULL
            WHEN LOWER(ASSETTAG) LIKE '%o.e.m%' THEN NULL
            ELSE TRIM(ASSETTAG)
        END AS asset_tag,

        -- Manufacturer normalization
        CASE 
            WHEN SMANUFACTURER LIKE '%Hewlett%' THEN 'HP'
            WHEN SMANUFACTURER LIKE '%Compaq%' THEN 'HP'
            WHEN SMANUFACTURER LIKE '%Dell%' THEN 'Dell'
            WHEN SMANUFACTURER LIKE '%LENOVO%' THEN 'Lenovo'
            WHEN SMANUFACTURER LIKE '%Foxconn%' THEN 'Foxconn'
            WHEN SMANUFACTURER LIKE '%MICRO-STAR%' THEN 'MSI'
            ELSE 'Other'
        END AS manufacturer_group,

        -- Metadata
        year AS source_year

    FROM source

),

cleaned AS (

    SELECT
        *,

        CASE 
            WHEN bios_date IS NULL THEN NULL
            ELSE TIMESTAMPDIFF(YEAR, bios_date, CURRENT_DATE)
        END AS bios_age_years

    FROM base

)

SELECT * FROM cleaned