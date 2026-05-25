WITH features AS (

    SELECT
        event_pk AS ticket_fk,
        source_system,
        source_id,
        created_at,
        closed_at,
        CASE
            WHEN closed_at IS NULL AND created_at IS NOT NULL
                THEN TIMESTAMPDIFF(HOUR, created_at, CURRENT_TIMESTAMP)
            WHEN closed_at IS NOT NULL AND created_at IS NOT NULL
                THEN TIMESTAMPDIFF(HOUR, created_at, closed_at)
            ELSE NULL
        END AS ticket_age_hours,
        COALESCE(resolution_time_hours, 0)          AS resolution_time_hours,
        priority_score,
        CAST(is_escalated AS UNSIGNED)              AS was_escalated,
        CAST(is_sla_breached AS UNSIGNED)           AS was_sla_breached,
        COALESCE(customer_satisfaction_score, 0)    AS satisfaction_score,
        COALESCE(issue_complexity_score, 0)         AS complexity_score,
        COALESCE(customer_tenure_months, 0)         AS tenure_months,
        COALESCE(previous_tickets, 0)               AS previous_tickets
    FROM {{ ref('silver_tickets') }}

),

scores AS (

    SELECT
        *,

        -- compute once, reuse below
        ROUND(
            (COALESCE(priority_score, 0) * 0.35)
            + (COALESCE(complexity_score, 0) * 0.20)
            + (CASE WHEN ticket_age_hours > 72 THEN 3 WHEN ticket_age_hours > 24 THEN 1 ELSE 0 END * 0.15)
            + (CASE WHEN previous_tickets > 5 THEN 5 WHEN previous_tickets > 2 THEN 3 ELSE 1 END * 0.15)
            + (CASE WHEN satisfaction_score < 3 THEN 3 WHEN satisfaction_score < 5 THEN 1 ELSE 0 END * 0.15)
        , 2) AS sla_risk_score,

        ROUND(
            LEAST(
                (COALESCE(priority_score, 0) * 0.25)
                + (CASE WHEN was_escalated = 1 THEN 3 ELSE 0 END * 0.25)
                + (CASE WHEN ticket_age_hours > 48 THEN 3 ELSE 0 END * 0.20)
                + (COALESCE(complexity_score, 0) * 0.20)
                + (CASE WHEN satisfaction_score < 3 THEN 2 ELSE 0 END * 0.10)
            , 10)
        , 2) AS escalation_probability

    FROM features

)

SELECT
    ticket_fk,
    source_system,
    source_id,
    created_at,
    closed_at,
    ticket_age_hours,
    resolution_time_hours,
    priority_score,
    was_escalated,
    was_sla_breached,
    satisfaction_score,
    complexity_score,
    tenure_months,
    previous_tickets,
    sla_risk_score,
    escalation_probability,

    CASE
        WHEN ticket_age_hours IS NULL THEN 'unknown'
        WHEN ticket_age_hours <= 4   THEN 'low'
        WHEN ticket_age_hours <= 24  THEN 'medium'
        WHEN ticket_age_hours <= 72  THEN 'high'
        ELSE 'critical'
    END AS age_severity,

    CASE
        WHEN previous_tickets >= 10 THEN 'frequent'
        WHEN previous_tickets >= 5  THEN 'repeat'
        WHEN previous_tickets >= 1  THEN 'returning'
        ELSE 'new'
    END AS customer_type,

    -- ✅ reference alias from scores CTE, no repetition
    CASE
        WHEN sla_risk_score >= 7 THEN 'critical'
        WHEN sla_risk_score >= 4 THEN 'high'
        WHEN sla_risk_score >= 2 THEN 'medium'
        ELSE 'low'
    END AS triage_priority,

    CASE
        WHEN escalation_probability >= 7 THEN 'high'
        WHEN escalation_probability >= 4 THEN 'medium'
        ELSE 'low'
    END AS escalation_risk_level

FROM scores