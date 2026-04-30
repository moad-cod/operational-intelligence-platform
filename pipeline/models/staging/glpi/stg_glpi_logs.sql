WITH source AS (

    SELECT *
    FROM {{ ref('base_glpi_logs') }}

),

renamed AS (

    SELECT
        -- 🔑 identifiers
        id AS log_id,

        CONCAT(id, '_', year) AS unique_id,

        items_id AS entity_id,
        itemtype AS entity_type,

        -- link info
        itemtype_link AS linked_entity_type,
        linked_action,

        -- user
        user_name,

        -- time
        CAST(date_mod AS DATETIME) AS updated_at,

        -- change tracking
        id_search_option AS field_id,
        old_value,
        new_value,

        -- derived
        CASE
            WHEN (old_value IS NULL OR old_value = '') 
                AND (new_value IS NOT NULL AND new_value != '') 
                THEN 'created'

            WHEN (old_value IS NOT NULL AND old_value != '') 
                AND (new_value IS NULL OR new_value = '') 
                THEN 'deleted'

            WHEN old_value != new_value 
                THEN 'updated'

            ELSE 'no_change'
        END AS change_type,

        -- source
        year AS source_year

    FROM source

)

SELECT * FROM renamed