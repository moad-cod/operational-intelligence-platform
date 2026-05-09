WITH ticket_features AS (

    SELECT
        ticket_id,

        followup_count,
        duration_days,

        positive_signals,
        negative_signals,

        is_resolved_flag

    FROM {{ ref('int_ticket_features') }}

),

ticket_operations AS (

    SELECT
        ticket_id,

        solved_at,
        closed_at,

        status,
        is_deleted,

        waiting_duration,
        close_delay_stat,
        solve_delay_stat,
        takeintoaccount_delay_stat,

        source_year

    FROM {{ ref('stg_glpi_tickets') }}

),

combined AS (

    SELECT
        o.ticket_id,

        -- Lifecycle
        o.solved_at,
        o.closed_at,

        o.status,
        o.is_deleted,

        -- SLA metrics
        o.waiting_duration,
        o.close_delay_stat,
        o.solve_delay_stat,
        o.takeintoaccount_delay_stat,

        -- Support metrics
        COALESCE(f.followup_count, 0) AS followup_count,

        -- Prevent negative durations
        CASE
            WHEN COALESCE(f.duration_days, 0) < 0 THEN 0
            ELSE COALESCE(f.duration_days, 0)
        END AS duration_days,

        COALESCE(f.positive_signals, 0) AS positive_signals,
        COALESCE(f.negative_signals, 0) AS negative_signals,

        -- FIXED RESOLUTION LOGIC
        CASE

            -- Real operational states
            WHEN LOWER(o.status) IN ('closed', 'solved')
            THEN 1

            -- NLP fallback
            WHEN COALESCE(f.positive_signals, 0)
                 > COALESCE(f.negative_signals, 0)
            THEN 1

            ELSE 0

        END AS is_resolved_flag,

        o.source_year

    FROM ticket_operations o

    LEFT JOIN ticket_features f
        ON o.ticket_id = f.ticket_id

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

        -- Support intelligence
        followup_count,
        duration_days,

        positive_signals,
        negative_signals,

        is_resolved_flag,

        -- SLA RISK LOGIC
        CASE

            WHEN is_resolved_flag = 0
                 AND LOWER(status) NOT IN ('closed', 'solved')
            THEN 'open'

            WHEN solve_delay_stat >= 10000000
                 OR close_delay_stat >= 15000000
            THEN 'critical'

            WHEN solve_delay_stat >= 5000000
            THEN 'high'

            WHEN solve_delay_stat >= 1000000
            THEN 'medium'

            ELSE 'low'

        END AS sla_risk_level,

        -- IMPROVED COMPLEXITY LOGIC
        CASE

            WHEN followup_count >= 20
                 OR negative_signals >= 10
                 OR duration_days >= 30
                 OR solve_delay_stat >= 5000000
            THEN 'high'

            WHEN followup_count >= 8
                 OR negative_signals >= 4
                 OR duration_days >= 7
                 OR solve_delay_stat >= 1000000
            THEN 'medium'

            ELSE 'low'

        END AS ticket_complexity_level,

        -- IMPROVED SUPPORT EFFICIENCY
        CASE

            WHEN is_resolved_flag = 0
            THEN 'unresolved'

            WHEN negative_signals > positive_signals
                 OR duration_days > 30
            THEN 'poor'

            WHEN positive_signals > negative_signals
                 AND solve_delay_stat < 1000000
                 AND duration_days <= 7
            THEN 'efficient'

            ELSE 'moderate'

        END AS support_efficiency,

        source_year

    FROM combined

)

SELECT * FROM final