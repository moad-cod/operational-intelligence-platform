WITH source AS (

    SELECT *
    FROM {{ ref('base_glpi_tickets') }}

),

cleaned AS (

    SELECT
        -- Composite PK (because ids repeat across years)
        CONCAT(year, '_', id) AS ticket_pk,

        -- Business keys
        id AS ticket_id,

        -- Dates
        CASE
            WHEN date IS NULL THEN NULL
            WHEN CAST(date AS CHAR) = '0000-00-00 00:00:00' THEN NULL
            ELSE date
        END AS created_at,
        CASE
            WHEN solvedate IS NULL THEN NULL
            WHEN CAST(solvedate AS CHAR) = '0000-00-00 00:00:00' THEN NULL
            WHEN solvedate < date THEN NULL
            ELSE solvedate
        END AS solved_at,
        CASE
            WHEN closedate IS NULL THEN NULL
            WHEN CAST(closedate AS CHAR) = '0000-00-00 00:00:00' THEN NULL
            WHEN closedate < date THEN NULL
            ELSE closedate
        END AS closed_at,

        -- Ticket status and lifecycle flags
        status,
        is_deleted,

        -- SLA metrics
        waiting_duration,
        close_delay_stat,
        solve_delay_stat,
        takeintoaccount_delay_stat,

        -- Source tracking
        year AS source_year

    FROM source

)

SELECT * FROM cleaned