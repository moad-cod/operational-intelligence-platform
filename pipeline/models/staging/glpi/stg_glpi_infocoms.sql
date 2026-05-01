WITH source AS (

    SELECT *
    FROM {{ ref('base_glpi_infocoms') }}

),

cleaned AS (

    SELECT
        -- 🔑 Composite PK (mandatory)
        CONCAT(year, '_', id) AS infocom_pk,

        -- Business keys
        id AS infocom_id,
        items_id AS item_id,

        -- Item info
        NULLIF(TRIM(itemtype), '') AS item_type,
        entities_id AS entity_id,

        -- Optional useful fields
        CASE 
            WHEN value = 0 THEN NULL
            ELSE value
        END AS asset_value,

        CASE 
            WHEN warranty_value = 0 THEN NULL
            ELSE warranty_value
        END AS warranty_value,

        -- Dates (safe handling)
        CASE 
            WHEN buy_date IS NULL THEN NULL
            WHEN CAST(buy_date AS CHAR) = '0000-00-00' THEN NULL
            ELSE buy_date
        END AS buy_date,

        CASE 
            WHEN warranty_date IS NULL THEN NULL
            WHEN CAST(warranty_date AS CHAR) = '0000-00-00' THEN NULL
            ELSE warranty_date
        END AS warranty_date,

        -- Metadata
        year AS source_year

    FROM source

)

SELECT * FROM cleaned