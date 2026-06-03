WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_glpi_tickets') }}

),

cleaned AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', id) AS ticket_pk,

        -- =====================================
        -- BUSINESS KEYS
        -- =====================================

        id AS ticket_id,

        -- =====================================
        -- DATES
        -- =====================================

        CASE

            WHEN date IS NULL THEN NULL

            WHEN CAST(date AS CHAR) = '0000-00-00 00:00:00'
                 THEN NULL

            ELSE CAST(date AS DATETIME)

        END AS created_at,

        CASE

            WHEN solvedate IS NULL THEN NULL

            WHEN CAST(solvedate AS CHAR) = '0000-00-00 00:00:00'
                 THEN NULL

            WHEN solvedate < date
                 THEN NULL

            ELSE CAST(solvedate AS DATETIME)

        END AS solved_at,

        CASE

            WHEN closedate IS NULL THEN NULL

            WHEN CAST(closedate AS CHAR) = '0000-00-00 00:00:00'
                 THEN NULL

            WHEN closedate < date
                 THEN NULL

            ELSE CAST(closedate AS DATETIME)

        END AS closed_at,

        -- =====================================
        -- TICKET STATUS
        -- =====================================

        status,

        CASE

            WHEN status IN ('closed', 'solved', 5, 6)
                 THEN TRUE

            ELSE FALSE

        END AS is_closed,

        CASE

            WHEN status IN ('closed', 6)
                 THEN TRUE

            ELSE FALSE

        END AS is_resolved,

        CASE

            WHEN status IN ('waiting', 4)
                 THEN TRUE

            ELSE FALSE

        END AS is_waiting,

        -- =====================================
        -- DELETION FLAG
        -- =====================================

        CASE

            WHEN is_deleted = 1 THEN TRUE

            ELSE FALSE

        END AS is_deleted,

        -- =====================================
        -- SLA METRICS
        -- =====================================

        CASE

            WHEN waiting_duration < 0 THEN NULL

            ELSE waiting_duration

        END AS waiting_duration,

        CASE

            WHEN close_delay_stat < 0 THEN NULL

            ELSE close_delay_stat

        END AS close_delay_stat,

        CASE

            WHEN solve_delay_stat < 0 THEN NULL

            ELSE solve_delay_stat

        END AS solve_delay_stat,

        CASE

            WHEN takeintoaccount_delay_stat < 0 THEN NULL

            ELSE takeintoaccount_delay_stat

        END AS takeintoaccount_delay_stat,

        -- =====================================
        -- TICKET LIFECYCLE METRICS
        -- =====================================

        CASE

            WHEN solvedate IS NULL THEN NULL

            WHEN solvedate < date THEN NULL

            ELSE TIMESTAMPDIFF(
                HOUR,
                date,
                solvedate
            )

        END AS resolution_time_hours,

        CASE

            WHEN closedate IS NULL THEN NULL

            WHEN closedate < date THEN NULL

            ELSE TIMESTAMPDIFF(
                HOUR,
                date,
                closedate
            )

        END AS closure_time_hours,

        -- =====================================
        -- PRIORITY FEATURES
        -- =====================================

        CASE

            WHEN priority >= 5 THEN 'critical'

            WHEN priority >= 4 THEN 'high'

            WHEN priority >= 3 THEN 'medium'

            WHEN priority >= 1 THEN 'low'

            ELSE 'unknown'

        END AS priority_tier,

        -- =====================================
        -- URGENCY FEATURES
        -- =====================================

        CASE

            WHEN urgency >= 5 THEN 'critical'

            WHEN urgency >= 4 THEN 'high'

            WHEN urgency >= 3 THEN 'medium'

            WHEN urgency >= 1 THEN 'low'

            ELSE 'unknown'

        END AS urgency_tier,

        -- =====================================
        -- IMPACT FEATURES
        -- =====================================

        CASE

            WHEN impact >= 5 THEN 'critical'

            WHEN impact >= 4 THEN 'high'

            WHEN impact >= 3 THEN 'medium'

            WHEN impact >= 1 THEN 'low'

            ELSE 'unknown'

        END AS impact_tier,

        -- =====================================
        -- SOURCE METADATA
        -- =====================================

        source_year,

        source_system

    FROM source

)

SELECT *

FROM cleaned