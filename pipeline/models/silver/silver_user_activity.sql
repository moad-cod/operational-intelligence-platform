WITH glpi_users AS (

    SELECT *
    FROM (

        SELECT
            user_pk,
            user_id,
            user_name,
            COALESCE(user_name, CONCAT('user-', user_id)) AS username,
            COALESCE(full_name, user_name) AS display_name,
            user_type,
            is_ldap_user,
            has_directory_account,
            suspicious_account,
            has_real_identity,

            ROW_NUMBER() OVER (
                PARTITION BY LOWER(COALESCE(user_name, ''))
                ORDER BY user_id
            ) AS rn

        FROM {{ ref('stg_glpi_users') }}

    ) dedup
    WHERE rn = 1

),

user_ticket_activity AS (

    SELECT
        MD5(CONCAT(
            'TICKET|',
            fup.ticket_followup_pk,
            '|',
            fup.user_id
        )) AS activity_pk,

        fup.user_id,
        fup.created_at AS activity_date,
        'ticket_followup' AS activity_type,
        fup.ticket_id AS entity_id,
        'ticket' AS entity_type,

        CASE
            WHEN fup.is_private THEN 'private'
            ELSE 'public'
        END AS visibility,

        fup.content_length,
        fup.has_meaningful_content,
        fup.contains_url,
        NULL AS details

    FROM {{ ref('stg_glpi_ticketfollowups') }} fup
    WHERE fup.user_id IS NOT NULL

),

user_log_activity AS (

    SELECT
        MD5(CONCAT(
            'LOG|',
            l.unique_id,
            '|',
            u.user_id
        )) AS activity_pk,

        u.user_id,
        l.updated_at AS activity_date,
        CONCAT('entity_', l.change_type) AS activity_type,
        l.entity_id,
        l.entity_type,

        NULL AS visibility,
        NULL AS content_length,
        NULL AS has_meaningful_content,
        NULL AS contains_url,

        CONCAT(
            COALESCE(l.linked_action, ''),
            ': ',
            COALESCE(l.old_value, ''),
            ' -> ',
            COALESCE(l.new_value, '')
        ) AS details

    FROM {{ ref('stg_glpi_logs') }} l

    INNER JOIN glpi_users u
        ON LOWER(COALESCE(l.user_name, ''))
        = LOWER(COALESCE(u.user_name, ''))

    WHERE l.has_user = TRUE
      AND l.has_change = TRUE

),

user_ocs_activity AS (

    SELECT
        MD5(CONCAT(
            'OCS|',
            h.hardware_pk,
            '|',
            u.user_id,
            '|',
            h.last_seen_date
        )) AS activity_pk,

        u.user_id,
        h.last_seen_date AS activity_date,
        'inventory_seen' AS activity_type,
        h.hardware_id AS entity_id,
        'computer' AS entity_type,

        NULL AS visibility,
        NULL AS content_length,
        NULL AS has_meaningful_content,
        NULL AS contains_url,

        CONCAT(
            'hostname: ', COALESCE(h.hostname, 'unknown'),
            ' | os: ', COALESCE(h.os_family, 'unknown')
        ) AS details

    FROM {{ ref('stg_ocs_hardware') }} h

    INNER JOIN glpi_users u
        ON LOWER(COALESCE(h.logged_user, ''))
        = LOWER(COALESCE(u.user_name, ''))

    WHERE h.has_logged_user = TRUE
      AND h.last_seen_date IS NOT NULL

),

all_activity AS (

    SELECT * FROM user_ticket_activity

    UNION ALL

    SELECT * FROM user_log_activity

    UNION ALL

    SELECT * FROM user_ocs_activity

),

enriched AS (

    SELECT
        a.activity_pk,
        a.user_id,

        u.username,
        u.display_name,
        u.user_type,
        u.is_ldap_user,

        u.suspicious_account AS is_suspicious_user,

        a.activity_date,
        a.activity_type,
        a.entity_id,
        a.entity_type,
        a.visibility,
        a.content_length,
        a.has_meaningful_content,
        a.details,

        CASE
            WHEN u.suspicious_account THEN TRUE

            WHEN u.user_type IN ('SYSTEM', 'TEST')
                THEN TRUE

            WHEN a.contains_url = TRUE
                 AND a.has_meaningful_content = FALSE
                THEN TRUE

            ELSE FALSE
        END AS is_suspicious_activity,

        CASE
            WHEN a.activity_type LIKE '%created%'
                THEN 'write'

            WHEN a.activity_type LIKE '%deleted%'
                THEN 'write'

            WHEN a.activity_type LIKE '%updated%'
                THEN 'write'

            ELSE 'read'
        END AS activity_category

    FROM all_activity a

    INNER JOIN glpi_users u
        ON a.user_id = u.user_id

),

deduped AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY activity_pk
            ORDER BY activity_date DESC
        ) AS rn
    FROM enriched

)

SELECT
    activity_pk,
    user_id,
    username,
    display_name,
    user_type,
    is_ldap_user,
    is_suspicious_user,
    activity_date,
    activity_type,
    activity_category,
    entity_id,
    entity_type,
    visibility,
    is_suspicious_activity,
    details

FROM deduped
WHERE rn = 1