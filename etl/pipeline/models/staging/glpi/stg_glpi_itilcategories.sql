WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_glpi_itilcategories') }}

),

cleaned AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', id) AS itil_category_pk,

        -- =====================================
        -- BUSINESS KEYS
        -- =====================================

        id AS category_id,

        completename AS full_category_name,

        -- =====================================
        -- CATEGORY NAME CLEANING
        -- =====================================

        CASE

            WHEN name IS NULL THEN NULL

            WHEN TRIM(name) = '' THEN NULL

            ELSE TRIM(name)

        END AS category_name,

        LOWER(TRIM(name)) AS normalized_category_name,

        -- =====================================
        -- HIERARCHY
        -- =====================================

        itilcategories_id AS parent_category_id,

        level,

        CASE

            WHEN itilcategories_id IS NULL
                 OR itilcategories_id = 0
                 THEN TRUE

            ELSE FALSE

        END AS is_root_category,

        -- =====================================
        -- CATEGORY TYPE
        -- =====================================

        CASE

            WHEN LOWER(name) LIKE '%réseau%'
                 OR LOWER(name) LIKE '%network%'
                 THEN 'NETWORK'

            WHEN LOWER(name) LIKE '%matériel%'
                 OR LOWER(name) LIKE '%hardware%'
                 THEN 'HARDWARE'

            WHEN LOWER(name) LIKE '%logiciel%'
                 OR LOWER(name) LIKE '%software%'
                 THEN 'SOFTWARE'

            WHEN LOWER(name) LIKE '%sécurité%'
                 OR LOWER(name) LIKE '%security%'
                 THEN 'SECURITY'

            WHEN LOWER(name) LIKE '%imprim%'
                 THEN 'PRINTER'

            WHEN LOWER(name) LIKE '%messagerie%'
                 OR LOWER(name) LIKE '%mail%'
                 THEN 'MAIL'

            WHEN LOWER(name) LIKE '%vpn%'
                 THEN 'VPN'

            ELSE 'OTHER'

        END AS category_type,

        -- =====================================
        -- ACTIVE FLAG
        -- =====================================

        CASE

            WHEN is_helpdeskvisible = 1
                 THEN TRUE

            ELSE FALSE

        END AS is_visible_helpdesk,

        -- =====================================
        -- COMPLEXITY FEATURE
        -- =====================================

        CASE

            WHEN level >= 4 THEN 'high'

            WHEN level >= 2 THEN 'medium'

            WHEN level >= 1 THEN 'low'

            ELSE 'unknown'

        END AS category_complexity,

        -- =====================================
        -- QUALITY FLAGS
        -- =====================================

        CASE

            WHEN name IS NULL THEN FALSE

            WHEN TRIM(name) = '' THEN FALSE

            ELSE TRUE

        END AS has_valid_name,

        -- =====================================
        -- SOURCE METADATA
        -- =====================================

        source_year,

        source_system

    FROM source

)

SELECT *

FROM cleaned