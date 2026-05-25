WITH glpi_source AS (

    SELECT
        MD5(CONCAT('GLPI_', ticket_pk)) AS event_pk,
        'GLPI' AS source_system,
        ticket_id AS source_id,
        source_year,
        created_at,
        solved_at,
        closed_at,
        priority_tier AS priority,
        CASE
            WHEN status = 6 THEN 'closed'
            WHEN status = 5 THEN 'closed'
            WHEN status = 4 THEN 'in_progress'
            WHEN status = 3 THEN 'in_progress'
            WHEN status = 2 THEN 'open'
            WHEN status = 1 THEN 'open'
            ELSE 'unknown'
        END AS ticket_status,
        urgency_tier,
        impact_tier,
        NULL AS category,
        NULL AS ticket_subject,
        NULL AS ticket_body,
        waiting_duration,
        close_delay_stat,
        solve_delay_stat,
        takeintoaccount_delay_stat,
        resolution_time_hours,
        closure_time_hours,
        NULL AS first_response_time_hours,
        NULL AS issue_complexity_score,
        NULL AS customer_satisfaction_score,
        NULL AS customer_tenure_months,
        NULL AS previous_tickets,
        FALSE AS is_escalated,
        FALSE AS is_sla_breached,
        NULL AS language,
        NULL AS region,
        NULL AS communication_channel
    FROM {{ ref('stg_glpi_tickets') }}
    WHERE is_deleted = FALSE

),

kaggle_source AS (

    SELECT
        MD5(CONCAT('KAGGLE_', unified_ticket_pk)) AS event_pk,
        source_dataset AS source_system,
        COALESCE(ticket_id, '0') AS source_id,
        NULL AS source_year,
        created_at,
        NULL AS solved_at,
        resolved_at AS closed_at,
        CASE
            WHEN LOWER(priority) IN ('critical', 'urgent') THEN 'critical'
            WHEN LOWER(priority) = 'high' THEN 'high'
            WHEN LOWER(priority) = 'medium' THEN 'medium'
            WHEN LOWER(priority) = 'low' THEN 'low'
            ELSE 'unknown'
        END AS priority,
        CASE
            WHEN LOWER(ticket_status) = 'closed' THEN 'closed'
            WHEN LOWER(ticket_status) = 'resolved' THEN 'resolved'
            WHEN LOWER(ticket_status) LIKE '%progress%' THEN 'in_progress'
            WHEN LOWER(ticket_status) = 'open' THEN 'open'
            WHEN LOWER(ticket_status) = 'escalated' THEN 'escalated'
            ELSE 'unknown'
        END AS ticket_status,
        NULL AS urgency_tier,
        NULL AS impact_tier,
        category,
        ticket_subject,
        ticket_body,
        NULL AS waiting_duration,
        NULL AS close_delay_stat,
        NULL AS solve_delay_stat,
        NULL AS takeintoaccount_delay_stat,
        resolution_time_hours,
        NULL AS closure_time_hours,
        first_response_time_hours,
        issue_complexity_score,
        customer_satisfaction_score,
        customer_tenure_months,
        previous_tickets,
        is_escalated,
        is_sla_breached,
        language,
        region,
        communication_channel
    FROM {{ ref('stg_kaggle_tickets') }}

)

-- ✅ no deduped CTE needed, no enriched CTE — compute everything inline
SELECT
    event_pk,
    source_system,
    source_id,
    source_year,
    created_at,
    solved_at,
    closed_at,
    priority,
    ticket_status,

    CASE
        WHEN ticket_status = 'closed' AND closed_at IS NOT NULL AND created_at IS NOT NULL
            THEN TIMESTAMPDIFF(HOUR, created_at, closed_at)
        ELSE resolution_time_hours
    END AS resolution_time_hours,

    CASE WHEN ticket_status = 'closed' THEN TRUE ELSE FALSE END AS is_closed,

    CASE
        WHEN priority = 'critical' THEN 5
        WHEN priority = 'high' THEN 4
        WHEN priority = 'medium' THEN 3
        WHEN priority = 'low' THEN 2
        ELSE 1
    END AS priority_score,

    CASE
        WHEN COALESCE(issue_complexity_score, 0) >= 7 THEN 'complex'
        WHEN COALESCE(issue_complexity_score, 0) >= 4 THEN 'moderate'
        WHEN issue_complexity_score IS NOT NULL THEN 'simple'
        ELSE 'unknown'
    END AS complexity_level,

    is_escalated,
    is_sla_breached,
    language,
    region,
    category,
    ticket_subject,
    ticket_body,
    waiting_duration,
    first_response_time_hours,
    customer_satisfaction_score,
    issue_complexity_score,
    customer_tenure_months,
    previous_tickets

FROM (
    SELECT * FROM glpi_source
    UNION ALL
    SELECT * FROM kaggle_source
) AS unified