WITH source AS (

    SELECT *
    FROM {{ ref('base_glpi_ticketfollowups') }}

),

cleaned AS (

    SELECT
        -- Composite PK (because ids repeat across years)
        CONCAT(year, '_', id) AS ticket_followup_pk,

        -- Business keys
        id AS followup_id,
        tickets_id AS ticket_id,

        -- Dates
        date AS created_at,

        -- Dimensions
        users_id AS user_id,
        requesttypes_id AS request_type_id,

        -- Content
        content,

        -- Flags
        is_private,

        -- Metadata
        year AS source_year

    FROM source

)

SELECT * FROM cleaned