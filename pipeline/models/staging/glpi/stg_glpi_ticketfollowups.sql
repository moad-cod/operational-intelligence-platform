WITH source AS (

    SELECT *
    FROM {{ ref('base_glpi_ticketfollowups') }}

),

cleaned AS (

    SELECT
        -- Composite PK
        CONCAT(year, '_', id) AS ticket_followup_pk,

        -- Business keys
        id AS followup_id,
        tickets_id AS ticket_id,

        -- Date
        CASE 
            WHEN date IS NULL THEN NULL
            WHEN CAST(date AS CHAR) = '0000-00-00 00:00:00' THEN NULL
            ELSE date
        END AS created_at,

        -- Dimensions
        users_id AS user_id,
        requesttypes_id AS request_type_id,

        -- Handle empty content HERE
        CASE 
            WHEN content IS NULL THEN NULL

            -- Remove useless rows
            WHEN TRIM(
                REPLACE(
                    REPLACE(content, '&gt;', ''),
                    '--', ''
                )
            ) = '' THEN NULL

            ELSE
                TRIM(
                    REPLACE(
                        REPLACE(content, '&gt;', ''),  -- decode html
                        '--', ''                      -- remove prefixes
                    )
                )
        END AS content,

        -- Normalize boolean HERE
        CASE 
            WHEN is_private = 1 THEN 1
            ELSE 0
        END AS is_private,

        -- Metadata
        year AS source_year

    FROM source

)

SELECT * FROM cleaned