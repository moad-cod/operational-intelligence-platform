-- Gold model: gold_sla_prediction_features
-- Sources: stg_glpi_tickets, stg_glpi_ticketfollowups, stg_kaggle_tickets
-- Consumers: SLA breach classifier (XGBoost/LightGBM)
-- Materialized: table

WITH glpi_features AS (

    SELECT
        MD5(CONCAT('GLPI_', ticket_pk)) AS sla_feature_pk,
        ticket_pk AS source_ticket_pk,
        'GLPI' AS source_system,
        ticket_id,
        created_at,
        closed_at,

        CASE
            WHEN priority_tier = 'critical' THEN 5
            WHEN priority_tier = 'high' THEN 4
            WHEN priority_tier = 'medium' THEN 3
            WHEN priority_tier = 'low' THEN 2
            ELSE 1
        END AS priority_score,

        CASE
            WHEN urgency_tier = 'critical' THEN 5
            WHEN urgency_tier = 'high' THEN 4
            WHEN urgency_tier = 'medium' THEN 3
            WHEN urgency_tier = 'low' THEN 2
            ELSE 1
        END AS urgency_score,

        CASE
            WHEN impact_tier = 'critical' THEN 5
            WHEN impact_tier = 'high' THEN 4
            WHEN impact_tier = 'medium' THEN 3
            WHEN impact_tier = 'low' THEN 2
            ELSE 1
        END AS impact_score,

        TIMESTAMPDIFF(HOUR, created_at, COALESCE(closed_at, CURRENT_TIMESTAMP)) AS ticket_age_hours,
        resolution_time_hours,
        waiting_duration,
        takeintoaccount_delay_stat AS takeintoaccount_delay,

        NULL AS issue_complexity_score,
        NULL AS customer_tenure_months,
        NULL AS previous_tickets,
        0 AS is_escalated,

        CASE WHEN COALESCE(close_delay_stat, 0) > 0 THEN 1 ELSE 0 END AS was_sla_breached

    FROM {{ ref('stg_glpi_tickets') }}
    WHERE is_deleted = FALSE

),

kaggle_features AS (

    SELECT
        MD5(CONCAT('KAGGLE_', unified_ticket_pk)) AS sla_feature_pk,
        unified_ticket_pk AS source_ticket_pk,
        source_dataset AS source_system,
        COALESCE(ticket_id, '0') AS ticket_id,
        created_at,
        resolved_at AS closed_at,

        CASE
            WHEN LOWER(priority) IN ('critical', 'urgent') THEN 5
            WHEN LOWER(priority) = 'high' THEN 4
            WHEN LOWER(priority) = 'medium' THEN 3
            WHEN LOWER(priority) = 'low' THEN 2
            ELSE 1
        END AS priority_score,

        NULL AS urgency_score,
        NULL AS impact_score,

        TIMESTAMPDIFF(HOUR, COALESCE(created_at, CURRENT_TIMESTAMP), COALESCE(resolved_at, CURRENT_TIMESTAMP)) AS ticket_age_hours,
        resolution_time_hours,
        NULL AS waiting_duration,
        NULL AS takeintoaccount_delay,

        issue_complexity_score,
        customer_tenure_months,
        previous_tickets,
        CASE WHEN is_escalated THEN 1 ELSE 0 END AS is_escalated,

        CASE WHEN is_sla_breached THEN 1 ELSE 0 END AS was_sla_breached

    FROM {{ ref('stg_kaggle_tickets') }}

),

followup_agg AS (

    SELECT
        ticket_id,
        COUNT(*) AS followup_count,
        AVG(CAST(content_length AS DECIMAL(10,2))) AS avg_followup_content_length,
        CASE
            WHEN COUNT(*) > 0
            THEN SUM(CASE WHEN is_private THEN 1 ELSE 0 END) / COUNT(*)
            ELSE 0
        END AS private_followup_ratio
    FROM {{ ref('stg_glpi_ticketfollowups') }}
    GROUP BY ticket_id

),

glpi_unified AS (

    SELECT
        f.*,
        COALESCE(fa.followup_count, 0) AS followup_count,
        COALESCE(fa.avg_followup_content_length, 0) AS avg_followup_content_length,
        COALESCE(fa.private_followup_ratio, 0) AS private_followup_ratio
    FROM glpi_features f
    LEFT JOIN followup_agg fa
        ON f.ticket_id = fa.ticket_id

),

kaggle_unified AS (

    SELECT
        k.*,
        0 AS followup_count,
        0 AS avg_followup_content_length,
        0 AS private_followup_ratio
    FROM kaggle_features k

),

unified AS (

    SELECT * FROM glpi_unified
    UNION ALL
    SELECT * FROM kaggle_unified

)

SELECT
    sla_feature_pk,
    source_ticket_pk,
    source_system,
    ticket_id,
    created_at,
    closed_at,
    priority_score,
    urgency_score,
    impact_score,
    ticket_age_hours,
    resolution_time_hours,
    waiting_duration,
    takeintoaccount_delay,
    followup_count,
    ROUND(private_followup_ratio, 4) AS private_followup_ratio,
    ROUND(avg_followup_content_length, 2) AS avg_followup_content_length,
    issue_complexity_score,
    customer_tenure_months,
    previous_tickets,
    is_escalated,
    was_sla_breached
FROM unified

