WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_glpi_infocoms') }}

),

cleaned AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', id) AS infocom_pk,

        -- =====================================
        -- BUSINESS KEYS
        -- =====================================

        id AS infocom_id,

        items_id AS item_id,

        -- =====================================
        -- ITEM TYPE NORMALIZATION
        -- =====================================

        CASE

            WHEN itemtype LIKE '%Computer%'
                 THEN 'Computer'

            WHEN itemtype LIKE '%Phone%'
                 THEN 'Phone'

            WHEN itemtype LIKE '%Printer%'
                 THEN 'Printer'

            WHEN itemtype LIKE '%Monitor%'
                 THEN 'Monitor'

            WHEN itemtype LIKE '%Network%'
                 THEN 'Network'

            ELSE 'Other'

        END AS item_type,

        entities_id AS entity_id,

        -- =====================================
        -- ASSET VALUE
        -- =====================================

        CASE

            WHEN value IS NULL THEN NULL

            WHEN value = 0 THEN NULL

            ELSE ROUND(value, 2)

        END AS asset_value,

        -- =====================================
        -- WARRANTY VALUE
        -- =====================================

        CASE

            WHEN warranty_value IS NULL THEN NULL

            WHEN warranty_value = 0 THEN NULL

            ELSE ROUND(warranty_value, 2)

        END AS warranty_value,

        -- =====================================
        -- BUY DATE
        -- =====================================

        CASE

            WHEN buy_date IS NULL THEN NULL

            WHEN CAST(buy_date AS CHAR) = '0000-00-00'
                 THEN NULL

            ELSE buy_date

        END AS buy_date,

        -- =====================================
        -- WARRANTY DATE
        -- =====================================

        CASE

            WHEN warranty_date IS NULL THEN NULL

            WHEN CAST(warranty_date AS CHAR) = '0000-00-00'
                 THEN NULL

            ELSE warranty_date

        END AS warranty_date,

        -- =====================================
        -- WARRANTY FLAG
        -- =====================================

        CASE

            WHEN warranty_date IS NULL THEN FALSE

            WHEN CAST(warranty_date AS CHAR) = '0000-00-00'
                 THEN FALSE

            ELSE TRUE

        END AS has_warranty,

        -- =====================================
        -- ASSET VALUE TIER
        -- =====================================

        CASE

            WHEN value >= 5000 THEN 'critical'

            WHEN value >= 2000 THEN 'high'

            WHEN value >= 1000 THEN 'medium'

            WHEN value IS NULL OR value = 0
                 THEN 'unknown'

            ELSE 'low'

        END AS asset_value_tier,

        -- =====================================
        -- ASSET AGE FLAG
        -- =====================================

        CASE

            WHEN buy_date IS NULL THEN FALSE

            WHEN CAST(buy_date AS CHAR) = '0000-00-00'
                 THEN FALSE

            ELSE TRUE

        END AS has_buy_date,

        -- =====================================
        -- METADATA
        -- =====================================

        source_year,

        source_system

    FROM source

)

SELECT *

FROM cleaned