WITH support_tickets AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        MD5(
            CONCAT(
                'support_',
                ticket_id
            )
        ) AS unified_ticket_pk,

        -- =====================================
        -- SOURCE IDENTIFICATION
        -- =====================================

        source_dataset,

        ticket_id,

        -- =====================================
        -- CUSTOMER INFORMATION
        -- =====================================

        NULLIF(TRIM(customer_name), '') AS customer_name,

        LOWER(NULLIF(TRIM(customer_email), '')) AS customer_email,

        NULLIF(TRIM(customer_segment), '') AS customer_segment,

        customer_age,

        LOWER(NULLIF(TRIM(customer_gender), '')) AS customer_gender,

        LOWER(NULLIF(TRIM(subscription_type), '')) AS subscription_type,

        customer_tenure_months,

        previous_tickets,

        customer_satisfaction_score,

        -- =====================================
        -- PRODUCT / ISSUE
        -- =====================================

        NULLIF(TRIM(product), '') AS product,

        LOWER(NULLIF(TRIM(category), '')) AS category,

        NULLIF(TRIM(issue_description), '') AS ticket_subject,

        NULLIF(TRIM(issue_description), '') AS ticket_body,

        NULLIF(TRIM(resolution_notes), '') AS resolution_notes,

        -- =====================================
        -- PRIORITY / STATUS
        -- =====================================

        LOWER(NULLIF(TRIM(priority), '')) AS priority,

        LOWER(NULLIF(TRIM(status), '')) AS ticket_status,

        LOWER(NULLIF(TRIM(channel), '')) AS communication_channel,

        LOWER(NULLIF(TRIM(region), '')) AS region,

        LOWER(NULLIF(TRIM(language), '')) AS language,

        LOWER(NULLIF(TRIM(payment_method), '')) AS payment_method,

        LOWER(NULLIF(TRIM(preferred_contact_time), '')) AS preferred_contact_time,

        -- =====================================
        -- TECHNICAL CONTEXT
        -- =====================================

        LOWER(NULLIF(TRIM(operating_system), '')) AS operating_system,

        LOWER(NULLIF(TRIM(browser), '')) AS browser,

        -- =====================================
        -- PERFORMANCE METRICS
        -- =====================================

        first_response_time_hours,

        resolution_time_hours,

        issue_complexity_score,

        -- =====================================
        -- FLAGS
        -- =====================================

        CASE
            WHEN LOWER(TRIM(escalated)) IN ('true', 'yes', '1') THEN TRUE
            ELSE FALSE
        END AS is_escalated,

        CASE
            WHEN LOWER(TRIM(sla_breached)) IN ('true', 'yes', '1') THEN TRUE
            ELSE FALSE
        END AS is_sla_breached,

        -- =====================================
        -- DATES
        -- =====================================

        CASE
            WHEN ticket_created_date IS NULL THEN NULL
            WHEN TRIM(ticket_created_date) = '' THEN NULL
            ELSE ticket_created_date
        END AS created_at,

        CASE
            WHEN ticket_resolved_date IS NULL THEN NULL
            WHEN TRIM(ticket_resolved_date) = '' THEN NULL
            ELSE ticket_resolved_date
        END AS resolved_at,

        -- =====================================
        -- NLP / MULTI-LANG
        -- =====================================

        NULL AS answer,

        NULL AS queue,

        NULL AS software_version,

        NULL AS tag_1,
        NULL AS tag_2,
        NULL AS tag_3,
        NULL AS tag_4,
        NULL AS tag_5,
        NULL AS tag_6,
        NULL AS tag_7,
        NULL AS tag_8

    FROM {{ source('bronze', 'customer_support_tickets_200k') }}

),

multi_lang_tickets AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        MD5(
            CONCAT(
                'multi_',
                IFNULL(subject, ''),
                '_',
                IFNULL(body, '')
            )
        ) AS unified_ticket_pk,

        -- =====================================
        -- SOURCE IDENTIFICATION
        -- =====================================

        source_dataset,

        NULL AS ticket_id,

        -- =====================================
        -- CUSTOMER INFORMATION
        -- =====================================

        NULL AS customer_name,

        NULL AS customer_email,

        NULL AS customer_segment,

        NULL AS customer_age,

        NULL AS customer_gender,

        NULL AS subscription_type,

        NULL AS customer_tenure_months,

        NULL AS previous_tickets,

        NULL AS customer_satisfaction_score,

        -- =====================================
        -- PRODUCT / ISSUE
        -- =====================================

        NULL AS product,

        LOWER(NULLIF(TRIM(type), '')) AS category,

        NULLIF(TRIM(subject), '') AS ticket_subject,

        NULLIF(TRIM(body), '') AS ticket_body,

        NULL AS resolution_notes,

        -- =====================================
        -- PRIORITY / STATUS
        -- =====================================

        LOWER(NULLIF(TRIM(priority), '')) AS priority,

        'resolved' AS ticket_status,

        NULL AS communication_channel,

        NULL AS region,

        LOWER(NULLIF(TRIM(language), '')) AS language,

        NULL AS payment_method,

        NULL AS preferred_contact_time,

        -- =====================================
        -- TECHNICAL CONTEXT
        -- =====================================

        NULL AS operating_system,

        NULL AS browser,

        -- =====================================
        -- PERFORMANCE METRICS
        -- =====================================

        NULL AS first_response_time_hours,

        NULL AS resolution_time_hours,

        NULL AS issue_complexity_score,

        -- =====================================
        -- FLAGS
        -- =====================================

        FALSE AS is_escalated,

        FALSE AS is_sla_breached,

        -- =====================================
        -- DATES
        -- =====================================

        NULL AS created_at,

        NULL AS resolved_at,

        -- =====================================
        -- NLP / KNOWLEDGE BASE
        -- =====================================

        NULLIF(TRIM(answer), '') AS answer,

        LOWER(NULLIF(TRIM(queue), '')) AS queue,

        version AS software_version,

        NULLIF(TRIM(tag_1), '') AS tag_1,
        NULLIF(TRIM(tag_2), '') AS tag_2,
        NULLIF(TRIM(tag_3), '') AS tag_3,
        NULLIF(TRIM(tag_4), '') AS tag_4,
        NULLIF(TRIM(tag_5), '') AS tag_5,
        NULLIF(TRIM(tag_6), '') AS tag_6,
        NULLIF(TRIM(tag_7), '') AS tag_7,
        NULLIF(TRIM(tag_8), '') AS tag_8

    FROM {{ source('bronze', 'dataset_tickets_multi_lang') }}

),

final AS (

    SELECT *
    FROM support_tickets

    UNION ALL

    SELECT *
    FROM multi_lang_tickets

)

SELECT DISTINCT *

FROM final