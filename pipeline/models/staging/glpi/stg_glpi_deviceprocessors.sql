WITH source AS (

    SELECT *
    FROM {{ ref('base_glpi_deviceprocessors') }}

),

base AS (

    SELECT
        --  Composite PK
        CONCAT(year, '_', id) AS processor_pk,

        -- Keys
        id AS processor_id,

        -- Raw text
        designation,

        --  Extract CPU family
        CASE 
            WHEN designation LIKE '%i7%' THEN 'i7'
            WHEN designation LIKE '%i5%' THEN 'i5'
            WHEN designation LIKE '%i3%' THEN 'i3'
            WHEN designation LIKE '%Xeon%' THEN 'Xeon'
            WHEN designation LIKE '%Pentium%' THEN 'Pentium'
            WHEN designation LIKE '%Atom%' THEN 'Atom'
            WHEN designation LIKE '%Core(TM)2 Duo%' THEN 'Core2Duo'
            ELSE 'Other'
        END AS cpu_family,

        --  Extract architecture
        CASE 
            WHEN designation LIKE '%x64%' THEN 'x64'
            WHEN designation LIKE '%x86%' THEN 'x86'
            ELSE 'unknown'
        END AS architecture,

        --  Extract cores
        CASE 
            WHEN designation LIKE '%[1 core%' THEN 1
            WHEN designation LIKE '%[2 core%' THEN 2
            WHEN designation LIKE '%[4 core%' THEN 4
            WHEN designation LIKE '%[6 core%' THEN 6
            ELSE NULL
        END AS core_count,

        -- Frequency
        CASE 
            WHEN specif_default = 0 THEN NULL
            ELSE specif_default
        END AS frequency_mhz,

        -- Metadata
        year AS source_year

    FROM source

),

cleaned AS (

    SELECT
        *,

        -- Now cpu_family is usable
        CASE 
            WHEN cpu_family IN ('i7','Xeon') THEN 'high'
            WHEN cpu_family IN ('i5','Core2Duo') THEN 'medium'
            WHEN cpu_family IN ('i3','Pentium','Atom') THEN 'low'
            ELSE 'unknown'
        END AS performance_tier

    FROM base

)

SELECT * FROM cleaned