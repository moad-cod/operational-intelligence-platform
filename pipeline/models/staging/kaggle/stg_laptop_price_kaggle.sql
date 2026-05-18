WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'raw_laptop_price_data') }}

),

cleaned AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        MD5(
            CONCAT(
                IFNULL(laptop_ID, ''),
                '_',
                IFNULL(Product, '')
            )
        ) AS laptop_pk,

        -- =====================================
        -- IDENTIFIERS
        -- =====================================

        laptop_ID AS laptop_id,

        NULLIF(TRIM(Company), '') AS company,

        NULLIF(TRIM(Product), '') AS product_name,

        LOWER(NULLIF(TRIM(TypeName), '')) AS laptop_type,

        -- =====================================
        -- SCREEN
        -- =====================================

        Inches AS screen_size_inches,

        NULLIF(TRIM(ScreenResolution), '') AS screen_resolution,

        CASE
            WHEN LOWER(ScreenResolution) LIKE '%ips%'
                 THEN TRUE
            ELSE FALSE
        END AS has_ips_panel,

        CASE
            WHEN LOWER(ScreenResolution) LIKE '%touch%'
                 THEN TRUE
            ELSE FALSE
        END AS has_touchscreen,

        -- =====================================
        -- CPU
        -- =====================================

        NULLIF(TRIM(Cpu), '') AS cpu_name,

        CASE

            WHEN LOWER(Cpu) LIKE '%i7%'
                 THEN 'i7'

            WHEN LOWER(Cpu) LIKE '%i5%'
                 THEN 'i5'

            WHEN LOWER(Cpu) LIKE '%i3%'
                 THEN 'i3'

            WHEN LOWER(Cpu) LIKE '%ryzen 7%'
                 THEN 'ryzen7'

            WHEN LOWER(Cpu) LIKE '%ryzen 5%'
                 THEN 'ryzen5'

            WHEN LOWER(Cpu) LIKE '%celeron%'
                 THEN 'celeron'

            ELSE 'other'

        END AS cpu_family,

        -- =====================================
        -- RAM
        -- =====================================

        NULLIF(TRIM(Ram), '') AS ram_raw,

        CASE
            WHEN Ram IS NULL THEN NULL
            ELSE CAST(
                REPLACE(
                    LOWER(Ram),
                    'gb',
                    ''
                ) AS SIGNED
            )
        END AS ram_gb,

        -- =====================================
        -- STORAGE
        -- =====================================

        NULLIF(TRIM(Memory), '') AS storage_configuration,

        CASE
            WHEN LOWER(Memory) LIKE '%ssd%'
                 THEN TRUE
            ELSE FALSE
        END AS has_ssd,

        CASE
            WHEN LOWER(Memory) LIKE '%hdd%'
                 THEN TRUE
            ELSE FALSE
        END AS has_hdd,

        -- =====================================
        -- GPU
        -- =====================================

        NULLIF(TRIM(Gpu), '') AS gpu_name,

        CASE

            WHEN LOWER(Gpu) LIKE '%nvidia%'
                 THEN 'NVIDIA'

            WHEN LOWER(Gpu) LIKE '%amd%'
                 THEN 'AMD'

            WHEN LOWER(Gpu) LIKE '%intel%'
                 THEN 'Intel'

            ELSE 'Other'

        END AS gpu_brand,

        -- =====================================
        -- OPERATING SYSTEM
        -- =====================================

        LOWER(NULLIF(TRIM(OpSys), '')) AS operating_system,

        -- =====================================
        -- WEIGHT
        -- =====================================

        NULLIF(TRIM(Weight), '') AS weight_raw,

        CASE
            WHEN Weight IS NULL THEN NULL
            ELSE CAST(
                REPLACE(
                    LOWER(Weight),
                    'kg',
                    ''
                ) AS DECIMAL(5,2)
            )
        END AS weight_kg,

        -- =====================================
        -- PRICE
        -- =====================================

        CASE
            WHEN Price_euros IS NULL THEN NULL
            WHEN Price_euros < 0 THEN NULL
            ELSE ROUND(Price_euros, 2)
        END AS price_euros,

        -- =====================================
        -- PRICE SEGMENT
        -- =====================================

        CASE

            WHEN Price_euros >= 2000
                 THEN 'premium'

            WHEN Price_euros >= 1000
                 THEN 'mid_range'

            WHEN Price_euros > 0
                 THEN 'budget'

            ELSE 'unknown'

        END AS price_segment

    FROM source

)

SELECT DISTINCT *

FROM cleaned