WITH followups AS (

    SELECT *
    FROM {{ ref('stg_glpi_ticketfollowups') }}

),

aggregated_followups AS (

    SELECT
        ticket_id,

        COUNT(*) AS followup_count,

        MIN(created_at) AS first_activity,
        MAX(created_at) AS last_activity,

        -- Duration
        DATEDIFF(MAX(created_at), MIN(created_at)) AS duration_days,

        -- Positive signals
        SUM(
            CASE 
                WHEN LOWER(content) LIKE '%ok%'
                  OR LOWER(content) LIKE '%résolu%'
                  OR LOWER(content) LIKE '%resolu%'
                  OR LOWER(content) LIKE '%solution%'
                THEN 1 
                ELSE 0 
            END
        ) AS positive_signals,

        -- Negative signals
        SUM(
            CASE 
                WHEN LOWER(content) LIKE '%nok%'
                  OR LOWER(content) LIKE '%probleme%'
                  OR LOWER(content) LIKE '%erreur%'
                THEN 1 
                ELSE 0 
            END
        ) AS negative_signals,

        -- Resolution flag
        MAX(
            CASE 
                WHEN LOWER(content) LIKE '%résolu%' 
                  OR LOWER(content) LIKE '%resolu%'
                  OR LOWER(content) LIKE '%ok%'
                THEN 1 
                ELSE 0 
            END
        ) AS is_resolved_flag

    FROM followups
    GROUP BY ticket_id

),

tickets AS (

    SELECT *
    FROM {{ ref('stg_glpi_tickets') }}

),

final AS (

    SELECT
        t.ticket_id,

        -- Join features
        COALESCE(f.followup_count, 0) AS followup_count,
        f.first_activity,
        f.last_activity,
        COALESCE(f.duration_days, 0) AS duration_days,
        COALESCE(f.positive_signals, 0) AS positive_signals,
        COALESCE(f.negative_signals, 0) AS negative_signals,
        COALESCE(f.is_resolved_flag, 0) AS is_resolved_flag,

        -- Ticket lifecycle
        t.solved_at,
        t.closed_at,
        t.status,
        t.is_deleted,

        -- SLA metrics
        t.waiting_duration,
        t.close_delay_stat,
        t.solve_delay_stat,
        t.takeintoaccount_delay_stat,

        t.source_year

    FROM tickets t
    LEFT JOIN aggregated_followups f
        ON t.ticket_id = f.ticket_id

)

SELECT * FROM final