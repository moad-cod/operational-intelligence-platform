-- Gold model: gold_user_activity_anomalies
-- Sources: stg_glpi_ticketfollowups, stg_glpi_logs, stg_glpi_users, stg_ocs_hardware
-- Consumers: Isolation Forest + LOF behavioral anomaly detector
-- Materialized: table
-- Note: is_suspicious_user is a weak heuristic — used only for post-hoc validation, NOT as ground truth.

WITH followup_per_user AS (

    SELECT
        user_id,
        COUNT(*) AS followup_count,
        SUM(CASE WHEN is_private THEN 1 ELSE 0 END) AS private_followup_count,
        AVG(CAST(content_length AS DECIMAL(10,2))) AS avg_followup_length,
        SUM(CASE WHEN contains_url AND NOT has_meaningful_content THEN 1 ELSE 0 END) AS suspicious_followup_count,
        COUNT(DISTINCT DATE(created_at)) AS followup_active_days,
        DATEDIFF(MAX(created_at), MIN(created_at)) AS followup_span_days
    FROM {{ ref('stg_glpi_ticketfollowups') }}
    WHERE user_id IS NOT NULL
    GROUP BY user_id

),

logs_per_user AS (

    SELECT
        user_name,
        COUNT(*) AS log_action_count,
        SUM(CASE WHEN change_type IN ('created', 'updated', 'deleted') THEN 1 ELSE 0 END) AS write_action_count,
        COUNT(DISTINCT entity_id) AS unique_entities_touched,
        COUNT(DISTINCT entity_type) AS unique_entity_types,
        MAX(updated_at) AS last_activity_date
    FROM {{ ref('stg_glpi_logs') }}
    WHERE has_user = TRUE AND has_change = TRUE
    GROUP BY user_name

),

ocs_per_user AS (

    SELECT
        logged_user,
        COUNT(*) AS ocs_inventory_count,
        MAX(last_seen_date) AS last_ocs_seen
    FROM {{ ref('stg_ocs_hardware') }}
    WHERE has_logged_user = TRUE AND logged_user IS NOT NULL
    GROUP BY logged_user

),

users_base AS (

    SELECT
        user_pk,
        user_id,
        COALESCE(user_name, CONCAT('user-', user_id)) AS user_name,
        user_type,
        CASE WHEN is_ldap_user THEN 1 ELSE 0 END AS is_ldap_user,
        CASE WHEN suspicious_account THEN 1 ELSE 0 END AS is_suspicious_user
    FROM {{ ref('stg_glpi_users') }}

),

aggregated AS (

    SELECT
        u.user_pk,
        u.user_id,
        u.user_name,
        u.user_type,

        CASE
            WHEN u.user_type = 'HUMAN' THEN 0
            WHEN u.user_type = 'SERVICE' THEN 1
            WHEN u.user_type = 'SYSTEM' THEN 2
            WHEN u.user_type = 'TEST' THEN 3
            ELSE 4
        END AS user_type_encoded,

        u.is_ldap_user,
        u.is_suspicious_user,

        COALESCE(f.followup_count, 0) AS followup_count,
        COALESCE(f.avg_followup_length, 0) AS avg_followup_length,

        CASE
            WHEN COALESCE(f.followup_count, 0) > 0
            THEN f.private_followup_count / f.followup_count
            ELSE 0
        END AS private_followup_ratio,

        CASE
            WHEN COALESCE(f.followup_count, 0) > 0
            THEN f.suspicious_followup_count / f.followup_count
            ELSE 0
        END AS url_content_ratio,

        COALESCE(f.followup_active_days, 0) AS followup_active_days,
        COALESCE(f.followup_span_days, 0) AS followup_span_days,

        COALESCE(l.log_action_count, 0) AS log_action_count,
        COALESCE(l.write_action_count, 0) AS write_action_count,

        CASE
            WHEN COALESCE(l.log_action_count, 0) > 0
            THEN l.write_action_count / l.log_action_count
            ELSE 0
        END AS write_action_ratio,

        COALESCE(l.unique_entities_touched, 0) AS unique_entities_touched,
        COALESCE(l.unique_entity_types, 0) AS unique_entity_types,

        COALESCE(o.ocs_inventory_count, 0) AS ocs_inventory_count,

        (
            COALESCE(f.followup_count, 0)
            + COALESCE(l.log_action_count, 0)
            + COALESCE(o.ocs_inventory_count, 0)
        ) AS total_activity_count,

        (
            CASE WHEN f.followup_count IS NOT NULL AND f.followup_count > 0 THEN 1 ELSE 0 END
            + CASE WHEN l.log_action_count IS NOT NULL AND l.log_action_count > 0 THEN 1 ELSE 0 END
            + CASE WHEN o.ocs_inventory_count IS NOT NULL AND o.ocs_inventory_count > 0 THEN 1 ELSE 0 END
        ) AS active_data_sources,

        GREATEST(
            COALESCE(f.followup_active_days, 0),
            COALESCE(f.followup_span_days, 0),
            DATEDIFF(COALESCE(l.last_activity_date, CURRENT_DATE), CURRENT_DATE) * -1
        ) AS distinct_days_active,

        GREATEST(
            COALESCE(f.followup_span_days, 0),
            COALESCE(DATEDIFF(COALESCE(o.last_ocs_seen, CURRENT_DATE), CURRENT_DATE) * -1, 0)
        ) AS activity_span_days

    FROM users_base u
    LEFT JOIN followup_per_user f
        ON u.user_id = f.user_id
    LEFT JOIN logs_per_user l
        ON LOWER(TRIM(u.user_name)) = LOWER(TRIM(l.user_name))
    LEFT JOIN ocs_per_user o
        ON LOWER(TRIM(u.user_name)) = LOWER(TRIM(o.logged_user))

)

SELECT
    user_pk,
    user_id,
    user_name,
    user_type,
    user_type_encoded,
    is_ldap_user,
    is_suspicious_user,
    total_activity_count,
    followup_count,
    log_action_count,
    ocs_inventory_count,
    ROUND(private_followup_ratio, 4) AS private_followup_ratio,
    ROUND(url_content_ratio, 4) AS url_content_ratio,
    ROUND(avg_followup_length, 2) AS avg_followup_length,
    unique_entities_touched,
    unique_entity_types,
    ROUND(write_action_ratio, 4) AS write_action_ratio,
    distinct_days_active,
    activity_span_days,
    ROUND(
        CASE
            WHEN activity_span_days > 0
            THEN total_activity_count / activity_span_days
            ELSE total_activity_count
        END
    , 4) AS activity_density,
    active_data_sources,
    NULL AS isolation_forest_score,
    NULL AS lof_score,
    NULL AS is_anomaly_if,
    NULL AS is_anomaly_lof
FROM aggregated