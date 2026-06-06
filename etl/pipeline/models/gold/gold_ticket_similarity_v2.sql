WITH ticket_base AS (

    SELECT
        c.event_pk,
        c.source_system,
        c.source_id,
        c.ticket_status,
        c.is_closed,
        c.created_at,
        c.resolved_at,
        c.priority,
        c.complexity_level,

        -- Searchable content
        TRIM(c.problem_text) AS problem_text,
        TRIM(c.solution_text) AS solution_text,

        -- Metadata
        c.category,
        c.language,
        c.product,
        c.queue,
        c.software_version,
        c.region,

        -- Tag metadata
        c.tag_1, c.tag_2, c.tag_3, c.tag_4,
        c.tag_5, c.tag_6, c.tag_7, c.tag_8,

        -- Triage metadata
        c.priority AS priority_tier,
        c.urgency_tier,
        c.impact_tier,
        t.triage_priority,
        t.escalation_risk_level,
        t.age_severity,
        t.customer_type,

        -- Ranking signals
        c.resolution_time_hours,
        c.waiting_duration,
        c.first_response_time_hours,
        c.issue_complexity_score,
        c.customer_satisfaction_score,
        c.customer_tenure_months,
        c.previous_tickets,
        t.sla_risk_score,
        t.escalation_probability,

        -- SLA signals
        c.is_sla_breached,
        c.is_escalated,

        -- Customer context
        c.customer_segment,
        c.subscription_type,
        c.operating_system,
        c.browser,

        -- Followup metrics
        c.followup_count,
        c.avg_followup_content_length,

        -- Source
        c.source_dataset

    FROM (
        SELECT *
        FROM {{ ref('silver_ticket_corpus') }}
        WHERE source_system != 'GLPI'
    ) c

    LEFT JOIN {{ ref('silver_triage_features') }} t
        ON c.event_pk = t.ticket_fk

),

quality_filtered AS (

    SELECT *
    FROM ticket_base

    WHERE
        -- Problem and solution must have meaningful text
        problem_text IS NOT NULL
        AND solution_text IS NOT NULL
        AND CHAR_LENGTH(problem_text) >= 20
        AND CHAR_LENGTH(solution_text) >= 20

        -- Keep only resolved or closed tickets
        AND (
            LOWER(ticket_status) = 'resolved'
            OR is_closed = TRUE
        )

)

SELECT
    MD5(event_pk) AS rag_id,

    problem_text,
    solution_text,

    category,
    priority,
    language,
    product,
    queue,
    software_version,
    region,

    tag_1, tag_2, tag_3, tag_4,
    tag_5, tag_6, tag_7, tag_8,

    priority_tier,
    urgency_tier,
    impact_tier,
    triage_priority,
    escalation_risk_level,
    age_severity,
    customer_type,

    resolution_time_hours,
    waiting_duration,
    first_response_time_hours,
    sla_risk_score,
    escalation_probability,

    is_sla_breached,
    is_escalated,

    issue_complexity_score,
    customer_satisfaction_score,
    customer_tenure_months,
    previous_tickets,

    customer_segment,
    subscription_type,
    operating_system,
    browser,

    followup_count,
    avg_followup_content_length,

    source_dataset,
    created_at,
    resolved_at,

    source_system,
    source_id

FROM quality_filtered
