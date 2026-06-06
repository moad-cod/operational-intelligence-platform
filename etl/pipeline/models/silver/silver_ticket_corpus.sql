WITH kaggle_metadata AS (

    SELECT
        MD5(CONCAT('KAGGLE_', unified_ticket_pk)) AS event_pk,
        source_dataset,
        resolution_notes,
        answer,
        product,
        queue,
        software_version,
        customer_segment,
        subscription_type,
        operating_system,
        browser,
        tag_1, tag_2, tag_3, tag_4, tag_5, tag_6, tag_7, tag_8

    FROM {{ ref('stg_kaggle_tickets') }}

),

glpi_metadata AS (

    SELECT
        MD5(CONCAT('GLPI_', ticket_pk)) AS event_pk,
        urgency_tier,
        impact_tier

    FROM {{ ref('stg_glpi_tickets') }}

    WHERE is_deleted = FALSE

),

glpi_corpus AS (

    SELECT
        ticket_id,
        source_year,
        followup_count,
        avg_followup_content_length,
        followup_text

    FROM {{ ref('silver_followups') }}

),

corpus_prep AS (

    SELECT
        t.event_pk,
        t.source_system,
        t.source_id,
        t.ticket_status,
        t.is_closed,
        t.created_at,
        t.closed_at AS resolved_at,
        t.priority,
        t.priority_score,
        t.complexity_level,
        t.category,
        t.language,
        t.region,

        -- Problem text: best available description of the issue
        CASE
            WHEN t.source_system IN ('customer_support_tickets_200k', 'dataset_tickets_multi_lang')
                THEN TRIM(CONCAT_WS(' ', t.ticket_subject, t.ticket_body))
            WHEN t.source_system = 'GLPI'
                THEN COALESCE(gc.followup_text, '')
            ELSE ''
        END AS problem_text,

        -- Solution text: best available resolution description
        CASE
            WHEN t.source_system = 'customer_support_tickets_200k'
                THEN COALESCE(k.resolution_notes, '')
            WHEN t.source_system = 'dataset_tickets_multi_lang'
                THEN COALESCE(k.answer, '')
            WHEN t.source_system = 'GLPI'
                THEN COALESCE(gc.followup_text, '')
            ELSE ''
        END AS solution_text,

        -- Kaggle metadata
        k.product,
        k.queue,
        k.software_version,
        k.customer_segment,
        k.subscription_type,
        k.operating_system,
        k.browser,

        k.tag_1, k.tag_2, k.tag_3, k.tag_4,
        k.tag_5, k.tag_6, k.tag_7, k.tag_8,

        -- GLPI metadata
        gm.urgency_tier,
        gm.impact_tier,

        -- Ranking signals
        t.resolution_time_hours,
        t.waiting_duration,
        t.first_response_time_hours,
        t.issue_complexity_score,
        t.customer_satisfaction_score,
        t.customer_tenure_months,
        t.previous_tickets,
        t.is_escalated,
        t.is_sla_breached,
        t.source_system AS source_dataset,

        -- Followup metrics
        COALESCE(gc.followup_count, 0) AS followup_count,
        COALESCE(gc.avg_followup_content_length, 0) AS avg_followup_content_length

    FROM {{ ref('silver_tickets') }} t

    LEFT JOIN kaggle_metadata k
        ON t.event_pk = k.event_pk

    LEFT JOIN glpi_metadata gm
        ON t.source_system = 'GLPI'
        AND t.event_pk = gm.event_pk

    LEFT JOIN glpi_corpus gc
        ON t.source_system = 'GLPI'
        AND CAST(t.source_id AS UNSIGNED) = gc.ticket_id
        AND t.source_year = gc.source_year

)

SELECT
    event_pk,
    source_system,
    source_id,
    ticket_status,
    is_closed,
    created_at,
    resolved_at,
    priority,
    priority_score,
    complexity_level,
    problem_text,
    solution_text,
    category,
    language,
    region,
    product,
    queue,
    software_version,
    customer_segment,
    subscription_type,
    operating_system,
    browser,
    tag_1, tag_2, tag_3, tag_4, tag_5, tag_6, tag_7, tag_8,
    urgency_tier,
    impact_tier,
    resolution_time_hours,
    waiting_duration,
    first_response_time_hours,
    issue_complexity_score,
    customer_satisfaction_score,
    customer_tenure_months,
    previous_tickets,
    is_escalated,
    is_sla_breached,
    source_dataset,
    followup_count,
    avg_followup_content_length

FROM corpus_prep
