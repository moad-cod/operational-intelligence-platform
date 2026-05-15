WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_glpi_deviceprocessors') }}

),

base AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', id) AS processor_pk,

        -- =====================================
        -- IDENTIFIERS
        -- =====================================

        id AS processor_id,

        designation,

        -- =====================================
        -- CPU FAMILY
        -- =====================================

        CASE

            WHEN designation LIKE '%i9%' THEN 'i9'

            WHEN designation LIKE '%i7%' THEN 'i7'

            WHEN designation LIKE '%i5%' THEN 'i5'

            WHEN designation LIKE '%i3%' THEN 'i3'

            WHEN designation LIKE '%Xeon%' THEN 'Xeon'

            WHEN designation LIKE '%Ryzen 9%' THEN 'Ryzen9'

            WHEN designation LIKE '%Ryzen 7%' THEN 'Ryzen7'

            WHEN designation LIKE '%Ryzen 5%' THEN 'Ryzen5'

            WHEN designation LIKE '%Ryzen 3%' THEN 'Ryzen3'

            WHEN designation LIKE '%Pentium%' THEN 'Pentium'

            WHEN designation LIKE '%Atom%' THEN 'Atom'

            WHEN designation LIKE '%Core(TM)2 Duo%' THEN 'Core2Duo'

            ELSE 'Other'

        END AS cpu_family,

        -- =====================================
        -- ARCHITECTURE
        -- =====================================

        CASE

            WHEN designation LIKE '%x64%' THEN 'x64'

            WHEN designation LIKE '%64-bit%' THEN 'x64'

            WHEN designation LIKE '%x86%' THEN 'x86'

            ELSE 'unknown'

        END AS architecture,

        -- =====================================
        -- CORE COUNT
        -- =====================================

        CASE

            WHEN designation LIKE '%[1 core%' THEN 1

            WHEN designation LIKE '%[2 core%' THEN 2

            WHEN designation LIKE '%[4 core%' THEN 4

            WHEN designation LIKE '%[6 core%' THEN 6

            WHEN designation LIKE '%[8 core%' THEN 8

            WHEN designation LIKE '%[12 core%' THEN 12

            WHEN designation LIKE '%[16 core%' THEN 16

            ELSE NULL

        END AS core_count,

        -- =====================================
        -- FREQUENCY
        -- =====================================

        CASE

            WHEN specif_default = 0 THEN NULL

            WHEN specif_default > 10000 THEN NULL

            ELSE specif_default

        END AS frequency_mhz,

        -- =====================================
        -- QUALITY FLAG
        -- =====================================

        CASE

            WHEN specif_default IS NULL THEN FALSE

            WHEN specif_default = 0 THEN FALSE

            ELSE TRUE

        END AS has_frequency_data,

        -- =====================================
        -- METADATA
        -- =====================================

        source_year,

        source_system

    FROM source

),

cleaned AS (

    SELECT

        *,

        -- =====================================
        -- PERFORMANCE TIER
        -- =====================================

        CASE

            WHEN cpu_family IN (
                'i9',
                'i7',
                'Xeon',
                'Ryzen9',
                'Ryzen7'
            ) THEN 'high'

            WHEN cpu_family IN (
                'i5',
                'Ryzen5',
                'Core2Duo'
            ) THEN 'medium'

            WHEN cpu_family IN (
                'i3',
                'Ryzen3',
                'Pentium',
                'Atom'
            ) THEN 'low'

            ELSE 'unknown'

        END AS performance_tier,

        -- =====================================
        -- SERVER CPU FLAG
        -- =====================================

        CASE

            WHEN cpu_family = 'Xeon' THEN TRUE

            ELSE FALSE

        END AS is_server_cpu

    FROM base

)

SELECT *

FROM cleaned