WITH followups AS (

    SELECT
        ticket_id,

        CAST(REPLACE(created_at, 'T', ' ') AS DATETIME) AS created_at,

        LOWER(content) AS content

    FROM {{ ref('stg_glpi_ticketfollowups') }}

),

aggregated_followups AS (

    SELECT
        ticket_id,

        COUNT(*) AS followup_count,

        MIN(created_at) AS first_activity,
        MAX(created_at) AS last_activity,

        -- Positive NLP signals
        SUM(
            CASE
                WHEN content LIKE '%ok%'
                  OR content LIKE '%résolu%'
                  OR content LIKE '%resolu%'
                  OR content LIKE '%solution%'
                THEN 1
                ELSE 0
            END
        ) AS positive_signals,

        -- Negative NLP signals
        SUM(
            CASE
                WHEN content LIKE '%nok%'
                  OR content LIKE '%probleme%'
                  OR content LIKE '%erreur%'
                THEN 1
                ELSE 0
            END
        ) AS negative_signals,

        -- NLP resolution signal
        MAX(
            CASE
                WHEN content LIKE '%résolu%'
                  OR content LIKE '%resolu%'
                  OR content LIKE '%ok%'
                THEN 1
                ELSE 0
            END
        ) AS nlp_resolved_flag

    FROM followups

    GROUP BY ticket_id

),

tickets_raw AS (

    SELECT *
    FROM {{ ref('stg_glpi_tickets') }}

),

tickets AS (

    SELECT *
    FROM (

        SELECT
            *,

            ROW_NUMBER() OVER (
                PARTITION BY ticket_id
                ORDER BY source_year DESC
            ) AS rn

        FROM tickets_raw

    ) t

    WHERE rn = 1

),

combined AS (

    SELECT
        t.ticket_id,

        -- Lifecycle
        CAST(REPLACE(t.solved_at, 'T', ' ') AS DATETIME) AS solved_at,
        CAST(REPLACE(t.closed_at, 'T', ' ') AS DATETIME) AS closed_at,

        LOWER(t.status) AS status,

        t.is_deleted,

        -- SLA metrics
        t.waiting_duration,
        t.close_delay_stat,
        t.solve_delay_stat,
        t.takeintoaccount_delay_stat,

        -- Followup metrics
        COALESCE(f.followup_count, 0) AS followup_count,

        f.first_activity,
        f.last_activity,

        COALESCE(f.positive_signals, 0) AS positive_signals,
        COALESCE(f.negative_signals, 0) AS negative_signals,

        COALESCE(f.nlp_resolved_flag, 0) AS nlp_resolved_flag,

        t.source_year

    FROM tickets t

    LEFT JOIN aggregated_followups f
        ON t.ticket_id = f.ticket_id

),

final AS (

    SELECT
        ticket_id,

        -- Lifecycle
        solved_at,
        closed_at,

        status,
        is_deleted,

        -- SLA metrics
        waiting_duration,
        close_delay_stat,
        solve_delay_stat,
        takeintoaccount_delay_stat,

        -- Followup intelligence
        followup_count,
        first_activity,
        last_activity,

        positive_signals,
        negative_signals,

        -- =========================================
        -- FIX 1: CORRECT RESOLUTION LOGIC
        -- =========================================
        CASE

            WHEN status IN ('closed', 'solved')
            THEN 1

            WHEN nlp_resolved_flag = 1
            THEN 1

            ELSE 0

        END AS is_resolved_flag,

        -- =========================================
        -- FIX 2: SAFE DURATION LOGIC
        -- =========================================
        CASE

            WHEN first_activity IS NULL
            THEN 0

            WHEN closed_at IS NOT NULL
            THEN GREATEST(
                    DATEDIFF(closed_at, first_activity),
                    0
                 )

            WHEN solved_at IS NOT NULL
            THEN GREATEST(
                    DATEDIFF(solved_at, first_activity),
                    0
                 )

            ELSE 0

        END AS duration_days,

        -- =========================================
        -- FIX 3: REBUILT SLA RISK LOGIC
        -- =========================================
        CASE

            WHEN status NOT IN ('closed', 'solved')
            THEN 'open'

            WHEN solve_delay_stat >= 10000000
            THEN 'critical'

            WHEN solve_delay_stat >= 3000000
            THEN 'high'

            WHEN solve_delay_stat >= 1000000
            THEN 'medium'

            ELSE 'low'

        END AS sla_risk_level,

        -- =========================================
        -- TICKET COMPLEXITY
        -- =========================================
        CASE

            WHEN followup_count >= 20
                 OR negative_signals >= 10
                 OR (
                        CASE
                            WHEN first_activity IS NULL THEN 0
                            WHEN closed_at IS NOT NULL
                                THEN GREATEST(
                                        DATEDIFF(closed_at, first_activity),
                                        0
                                     )
                            WHEN solved_at IS NOT NULL
                                THEN GREATEST(
                                        DATEDIFF(solved_at, first_activity),
                                        0
                                     )
                            ELSE 0
                        END
                    ) >= 30
            THEN 'high'

            WHEN followup_count >= 8
                 OR negative_signals >= 4
                 OR (
                        CASE
                            WHEN first_activity IS NULL THEN 0
                            WHEN closed_at IS NOT NULL
                                THEN GREATEST(
                                        DATEDIFF(closed_at, first_activity),
                                        0
                                     )
                            WHEN solved_at IS NOT NULL
                                THEN GREATEST(
                                        DATEDIFF(solved_at, first_activity),
                                        0
                                     )
                            ELSE 0
                        END
                    ) >= 7
            THEN 'medium'

            ELSE 'low'

        END AS ticket_complexity_level,

        -- =========================================
        -- FIX 4: IMPROVED SUPPORT EFFICIENCY
        -- =========================================
        CASE

            WHEN status NOT IN ('closed', 'solved')
            THEN 'unresolved'

            WHEN solve_delay_stat <= 100000
                 AND negative_signals = 0
            THEN 'efficient'

            WHEN negative_signals > positive_signals
            THEN 'poor'

            ELSE 'moderate'

        END AS support_efficiency,

        source_year

    FROM combined

)

SELECT *
FROM final