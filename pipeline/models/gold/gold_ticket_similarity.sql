-- Gold model: gold_ticket_similarity
-- Sources: stg_glpi_tickets, stg_glpi_ticketfollowups, stg_kaggle_tickets
-- Consumers: Similarity search / SolutionRecommender
-- Materialized: table
-- Note: NLP embedding step runs in Python outside dbt. This model prepares the structured base.
-- Similarity method: 'structured_vector' for GLPI, 'nlp_embedding' for Kaggle

WITH glpi_structured AS (

    SELECT
        MD5(CONCAT('GLPI_SIM_', t.ticket_pk)) AS similarity_pk,
        t.ticket_pk,
        'GLPI' AS source_system,
        t.ticket_id,
        t.created_at,
        t.closed_at,
        NULL AS text_corpus,

        CASE
            WHEN t.priority_tier = 'critical' THEN 5
            WHEN t.priority_tier = 'high' THEN 4
            WHEN t.priority_tier = 'medium' THEN 3
            WHEN t.priority_tier = 'low' THEN 2
            ELSE 1
        END AS priority_encoded,

        CASE
            WHEN t.urgency_tier = 'critical' THEN 5
            WHEN t.urgency_tier = 'high' THEN 4
            WHEN t.urgency_tier = 'medium' THEN 3
            WHEN t.urgency_tier = 'low' THEN 2
            ELSE 1
        END AS urgency_encoded,

        CASE
            WHEN t.impact_tier = 'critical' THEN 5
            WHEN t.impact_tier = 'high' THEN 4
            WHEN t.impact_tier = 'medium' THEN 3
            WHEN t.impact_tier = 'low' THEN 2
            ELSE 1
        END AS impact_encoded,

        CASE
            WHEN COALESCE(t.resolution_time_hours, 0) <= 4 THEN 1
            WHEN COALESCE(t.resolution_time_hours, 0) <= 24 THEN 2
            WHEN COALESCE(t.resolution_time_hours, 0) <= 72 THEN 3
            WHEN COALESCE(t.resolution_time_hours, 0) <= 168 THEN 4
            ELSE 5
        END AS resolution_time_bucket,

        CASE
            WHEN COALESCE(fa.followup_count, 0) = 0 THEN 1
            WHEN fa.followup_count <= 3 THEN 2
            WHEN fa.followup_count <= 10 THEN 3
            WHEN fa.followup_count <= 30 THEN 4
            ELSE 5
        END AS followup_count_bucket,

        CASE
            WHEN COALESCE(t.close_delay_stat, 0) > 0 THEN 1
            ELSE 0
        END AS was_overdue,

        'structured_vector' AS similarity_method,

        NULL AS embedding_model

    FROM {{ ref('stg_glpi_tickets') }} t
    LEFT JOIN (
        SELECT
            ticket_id,
            COUNT(*) AS followup_count
        FROM {{ ref('stg_glpi_ticketfollowups') }}
        GROUP BY ticket_id
    ) fa ON t.ticket_pk = fa.ticket_id
    WHERE t.is_deleted = FALSE

),

kaggle_nlp_prep AS (

    SELECT
        MD5(CONCAT('KAGGLE_SIM_', unified_ticket_pk)) AS similarity_pk,
        unified_ticket_pk,
        source_dataset AS source_system,
        COALESCE(ticket_id, '0') AS ticket_id,
        created_at,
        resolved_at AS closed_at,
        CONCAT(
            COALESCE(NULLIF(TRIM(ticket_subject), ''), ''),
            ' ',
            COALESCE(NULLIF(TRIM(ticket_body), ''), '')
        ) AS text_corpus,

        NULL AS priority_encoded,
        NULL AS urgency_encoded,
        NULL AS impact_encoded,
        NULL AS resolution_time_bucket,
        NULL AS followup_count_bucket,
        NULL AS was_overdue,

        'nlp_embedding' AS similarity_method,

        'paraphrase-multilingual-MiniLM-L12-v2' AS embedding_model

    FROM {{ ref('stg_kaggle_tickets') }}

),

unified AS (

    SELECT * FROM glpi_structured
    UNION ALL
    SELECT * FROM kaggle_nlp_prep

)

SELECT
    similarity_pk,
    ticket_pk,
    source_system,
    ticket_id,
    created_at,
    closed_at,
    text_corpus,
    priority_encoded,
    urgency_encoded,
    impact_encoded,
    resolution_time_bucket,
    followup_count_bucket,
    was_overdue,
    similarity_method,
    embedding_model,
    NULL AS similar_ticket_ids,
    NULL AS similarity_scores
FROM unified