WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_glpi_logs') }}

),

normalized AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', id) AS unique_id,

        id AS log_id,

        -- =====================================
        -- ENTITY INFORMATION
        -- =====================================

        items_id AS entity_id,

        NULLIF(TRIM(itemtype), '') AS entity_type,

        -- =====================================
        -- LINKED ENTITY
        -- =====================================

        NULLIF(TRIM(itemtype_link), '') AS linked_entity_type,

        NULLIF(TRIM(linked_action), '') AS linked_action,

        -- =====================================
        -- USER INFORMATION
        -- =====================================

        NULLIF(TRIM(user_name), '') AS user_name,

        CASE

            WHEN user_name IS NULL THEN FALSE

            WHEN TRIM(user_name) = '' THEN FALSE

            ELSE TRUE

        END AS has_user,

        -- =====================================
        -- TIMESTAMP
        -- =====================================

        CAST(date_mod AS DATETIME) AS updated_at,

        -- =====================================
        -- FIELD TRACKING
        -- =====================================

        id_search_option AS field_id,

        -- =====================================
        -- VALUE NORMALIZATION
        -- =====================================

        CASE

            WHEN old_value IS NULL THEN NULL

            WHEN TRIM(old_value) IN ('', '-')
                 THEN NULL

            ELSE TRIM(old_value)

        END AS old_value,

        CASE

            WHEN new_value IS NULL THEN NULL

            WHEN TRIM(new_value) IN ('', '-')
                 THEN NULL

            ELSE TRIM(new_value)

        END AS new_value,

        source_year,

        source_system

    FROM source

),

classified AS (

    SELECT

        *,

        -- =====================================
        -- CHANGE TYPE
        -- =====================================

        CASE

            WHEN old_value IS NULL
                 AND new_value IS NOT NULL
                 THEN 'created'

            WHEN old_value IS NOT NULL
                 AND new_value IS NULL
                 THEN 'deleted'

            WHEN old_value IS NOT NULL
                 AND new_value IS NOT NULL
                 AND old_value != new_value
                 THEN 'updated'

            ELSE 'no_change'

        END AS change_type,

        -- =====================================
        -- CHANGE FLAG
        -- =====================================

        CASE

            WHEN old_value != new_value
                 THEN TRUE

            WHEN old_value IS NULL
                 AND new_value IS NOT NULL
                 THEN TRUE

            WHEN old_value IS NOT NULL
                 AND new_value IS NULL
                 THEN TRUE

            ELSE FALSE

        END AS has_change

    FROM normalized

)

SELECT *

FROM classified