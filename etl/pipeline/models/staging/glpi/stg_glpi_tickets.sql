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
        -- TICKET TYPE (ITIL: 1=incident, 2=request)
        -- =====================================

        CASE
            WHEN type = 1 THEN 'incident'
            WHEN type = 2 THEN 'request'
            ELSE 'unknown'
        END AS ticket_type,

        CASE
            WHEN type = 1 THEN TRUE
            ELSE FALSE
        END AS is_incident,

        -- =====================================
        -- LINKED ITEM (Computer, etc.)
        -- =====================================

        CASE
            WHEN itemtype IS NULL OR TRIM(itemtype) = '' THEN NULL
            ELSE TRIM(itemtype)
        END AS item_type,

        CASE
            WHEN items_id IS NULL OR items_id <= 0 THEN NULL
            ELSE items_id
        END AS items_id,

        -- =====================================
        -- CATEGORY
        -- =====================================

        CASE
            WHEN itilcategories_id IS NULL OR itilcategories_id <= 0 THEN NULL
            ELSE itilcategories_id
        END AS itilcategories_id,

        -- =====================================
        -- CONTENT (ticket description text)
        -- =====================================

        CASE
            WHEN content IS NULL THEN NULL
            WHEN TRIM(content) = '' THEN NULL
            WHEN TRIM(content) IN ('-', 'null', 'NULL') THEN NULL
            ELSE TRIM(content)
        END AS content,

        -- =====================================
        -- RAW SCORES (for numerical filtering in silver/gold)
        -- =====================================

        CASE
            WHEN priority IS NULL OR priority < 1 THEN 1
            ELSE priority
        END AS priority,

        CASE
            WHEN urgency IS NULL OR urgency < 1 THEN 1
            ELSE urgency
        END AS urgency,

        CASE
            WHEN impact IS NULL OR impact < 1 THEN 1
            ELSE impact
        END AS impact,

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