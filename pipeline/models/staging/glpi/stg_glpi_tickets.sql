WITH source AS (

    SELECT *
    FROM {{ ref('base_glpi_tickets') }}

),

cleaned AS (

    SELECT
        -- 🔑 Correct PK
        CONCAT(year, '_', id) AS ticket_pk,

        id AS ticket_id,
        name AS ticket_name,

        -- Dates (no TIMESTAMP in MySQL)
        date AS created_at,
        solvedate AS solved_at,
        closedate AS closed_at,

        status,
        priority,

        users_id_recipient AS recipient_user_id,
        users_id_lastupdater AS last_updater_user_id,
        entities_id AS entity_id,

        -- 🔥 your additional fields from base
        begin_waiting_date,
        waiting_duration,
        close_delay_stat,
        solve_delay_stat,
        takeintoaccount_delay_stat,
        actiontime,
        is_deleted,

        year AS source_year   -- rename for consistency

    FROM source

)

SELECT * FROM cleaned