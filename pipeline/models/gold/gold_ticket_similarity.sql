-- =============================================================================
-- gold_ticket_similarity
-- Hybrid similarity architecture for IT ticket retrieval.
--
-- ARCHITECTURE OVERVIEW
-- =====================
-- Two independent similarity pipelines coexist in this model:
--
--   1. KAGGLE (Real NLP text):
--      text_corpus = ticket_subject || ticket_body
--      → sentence-transformers → FAISS index
--      → similarity_method = 'nlp_embedding'
--      → text_source_type  = 'real_text'
--
--   2. GLPI (Structured metadata only):
--      synthetic_text_corpus = CONCAT(metadata tokens, followup tokens, infra tokens)
--      → TF-IDF / SentenceTransformer on synthetic corpus → FAISS index
--      → similarity_method = 'synthetic_context'
--      → text_source_type  = 'synthetic_context'
--
-- HARD LIMITATION
-- ===============
-- GLPI tickets have NULL ticket_subject, ticket_body, and category.
-- No real NLP text exists for GLPI. All GLPI representations are
-- synthetic reconstructions from structured metadata only.
-- Do NOT treat GLPI similarity scores as equivalent to Kaggle NLP scores.
--
-- CONFIGURABLE THRESHOLDS (documented in dbt_project.yml or seed table)
-- =====================================================================
--   - long_resolution_hours: 168 (7 days)
--   - moderate_resolution_hours: 72
--   - fast_resolution_hours: 24
--   - long_waiting_seconds: 86400 (24h)
--   - moderate_waiting_seconds: 3600 (1h)
--   - high_followup_count: 10
--   - detailed_content_length: 500
--   - url_heavy_ratio: 0.3
--   - meaningful_content_ratio: 0.3
--   - high_core_threshold: 8
--   - high_software_count: 20
-- =============================================================================

WITH

-- =============================================================================
-- GLPI PIPELINE: Synthetic context reconstruction
-- =============================================================================

-- 1. Ticket metadata tokens
glpi_ticket_tokens AS (

    SELECT
        ticket_pk,
        ticket_id,
        created_at,
        closed_at,
        CONCAT_WS(' ',
            CASE priority_tier
                WHEN 'critical' THEN 'prio_critical'
                WHEN 'high' THEN 'prio_high'
                WHEN 'medium' THEN 'prio_medium'
                WHEN 'low' THEN 'prio_low'
                ELSE 'prio_unknown'
            END,

            CASE urgency_tier
                WHEN 'critical' THEN 'urg_critical'
                WHEN 'high' THEN 'urg_high'
                WHEN 'medium' THEN 'urg_medium'
                WHEN 'low' THEN 'urg_low'
                ELSE 'urg_unknown'
            END,

            CASE impact_tier
                WHEN 'critical' THEN 'impact_critical'
                WHEN 'high' THEN 'impact_high'
                WHEN 'medium' THEN 'impact_medium'
                WHEN 'low' THEN 'impact_low'
                ELSE 'impact_unknown'
            END,

            CASE
                WHEN status IN (5, 6) THEN 'ticket_closed'
                WHEN status = 4 THEN 'ticket_pending'
                WHEN status = 3 THEN 'ticket_in_progress'
                WHEN status = 2 THEN 'ticket_assigned'
                WHEN status = 1 THEN 'ticket_new'
                ELSE 'ticket_unknown_status'
            END,

            CASE
                WHEN status IN (5, 6) AND COALESCE(close_delay_stat, 0) > 0
                    THEN 'sla_breached'
                WHEN status IN (5, 6)
                    THEN 'sla_met'
                ELSE NULL
            END,

            CASE
                WHEN COALESCE(solve_delay_stat, 0) > 0
                    THEN 'resolution_overdue'
                ELSE NULL
            END,

            CASE
                WHEN COALESCE(resolution_time_hours, 0) > 168 THEN 'very_long_resolution'
                WHEN COALESCE(resolution_time_hours, 0) > 72 THEN 'long_resolution'
                WHEN COALESCE(resolution_time_hours, 0) > 24 THEN 'moderate_resolution'
                WHEN COALESCE(resolution_time_hours, 0) > 0 THEN 'fast_resolution'
                ELSE 'unresolved_ticket'
            END,

            CASE
                WHEN COALESCE(waiting_duration, 0) > 86400 THEN 'long_waiting_time'
                WHEN COALESCE(waiting_duration, 0) > 3600 THEN 'moderate_waiting_time'
                ELSE NULL
            END
        ) AS ticket_metadata_tokens

    FROM {{ ref('stg_glpi_tickets') }}
    WHERE is_deleted = FALSE

),

-- 2. Follow-up behavioral enrichment tokens
followup_tokens AS (

    SELECT
        f.ticket_id,
        COUNT(*) AS followup_count,
        ROUND(
            CASE WHEN COUNT(*) > 0
                THEN SUM(CASE WHEN f.is_private THEN 1 ELSE 0 END) / COUNT(*)
                ELSE 0
            END, 4
        ) AS private_ratio,
        ROUND(
            CASE WHEN COUNT(*) > 0
                THEN AVG(f.content_length)
                ELSE 0
            END, 2
        ) AS avg_content_length,
        ROUND(
            CASE WHEN COUNT(*) > 0
                THEN SUM(CASE WHEN f.contains_url THEN 1 ELSE 0 END) / COUNT(*)
                ELSE 0
            END, 4
        ) AS url_ratio,
        ROUND(
            CASE WHEN COUNT(*) > 0
                THEN SUM(CASE WHEN f.has_meaningful_content THEN 1 ELSE 0 END) / COUNT(*)
                ELSE 0
            END, 4
        ) AS meaningful_ratio,
        CONCAT_WS(' ',
            CASE WHEN COUNT(*) > 10 THEN 'multiple_followups' ELSE NULL END,
            CASE
                WHEN COUNT(*) > 0
                AND SUM(CASE WHEN f.is_private THEN 1 ELSE 0 END) / COUNT(*) > 0.5
                    THEN 'private_heavy_ticket'
                ELSE NULL
            END,
            CASE WHEN AVG(f.content_length) > 500 THEN 'detailed_interactions' ELSE NULL END,
            CASE
                WHEN COUNT(*) > 0
                AND SUM(CASE WHEN f.contains_url THEN 1 ELSE 0 END) / COUNT(*) > 0.3
                    THEN 'url_heavy_activity'
                ELSE NULL
            END,
            CASE
                WHEN COUNT(*) > 0
                AND SUM(CASE WHEN f.has_meaningful_content THEN 1 ELSE 0 END) / COUNT(*) < 0.3
                    THEN 'low_information_ticket'
                ELSE NULL
            END
        ) AS followup_behavior_tokens

    FROM {{ ref('stg_glpi_ticketfollowups') }} f
    GROUP BY f.ticket_id

),

-- 3. Infrastructure context enrichment
-- Join path: bronze_glpi_tickets.items_id → stg_glpi_computers.computer_id
--            → stg_ocs_hardware.uuid/hostname → stg_ocs_bios / stg_ocs_software
-- Deduplicated via ROW_NUMBER to prevent fan-out from OR-based join condition
ticket_infra_raw AS (

    SELECT
        bt.id AS ticket_id,
        bt.source_year,
        ocs_hw.os_family,
        ocs_hw.memory_gb,
        ocs_hw.cpu_cores,
        ocs_hw.memory_tier,
        b.bios_age_years,
        b.bios_risk_level,
        sw_agg.total_software_count,
        sw_agg.high_risk_software_count,
        CONCAT_WS(' ',
            CASE ocs_hw.os_family
                WHEN 'Windows' THEN 'windows_environment'
                WHEN 'Linux' THEN 'linux_environment'
                WHEN 'MacOS' THEN 'mac_environment'
                ELSE NULL
            END,
            CASE
                WHEN ocs_hw.memory_tier = 'critical' THEN 'low_memory_device'
                ELSE NULL
            END,
            CASE
                WHEN COALESCE(ocs_hw.cpu_cores, 0) >= 8 THEN 'high_core_server'
                ELSE NULL
            END,
            CASE
                WHEN COALESCE(b.bios_risk_level, 'unknown') = 'critical'
                    THEN 'critical_bios_risk'
                WHEN COALESCE(b.bios_age_years, 0) >= 10
                    THEN 'legacy_bios'
                ELSE NULL
            END,
            CASE
                WHEN COALESCE(sw_agg.high_risk_software_count, 0) > 0
                    THEN 'high_risk_software_present'
                ELSE NULL
            END,
            CASE
                WHEN COALESCE(sw_agg.total_software_count, 0) > 20
                    THEN 'multiple_software_components'
                ELSE NULL
            END
        ) AS infra_tokens,

        ROW_NUMBER() OVER (
            PARTITION BY bt.id
            ORDER BY
                CASE WHEN c.computer_uuid IS NOT NULL AND c.computer_uuid != 'unknown'
                    THEN 0 ELSE 1 END,
                ocs_hw.last_seen_date DESC
        ) AS rn

    FROM {{ source('bronze', 'bronze_glpi_tickets') }} bt
    LEFT JOIN {{ ref('stg_glpi_computers') }} c
        ON bt.items_id = c.computer_id
    LEFT JOIN {{ ref('stg_ocs_hardware') }} ocs_hw
        ON (
            c.computer_uuid IS NOT NULL
            AND c.computer_uuid != 'unknown'
            AND ocs_hw.uuid IS NOT NULL
            AND ocs_hw.uuid != ''
            AND c.computer_uuid = ocs_hw.uuid
        )
        OR (
            LOWER(c.computer_name) = ocs_hw.normalized_hostname
            AND c.source_year = ocs_hw.source_year
        )
    LEFT JOIN {{ ref('stg_ocs_bios') }} b
        ON ocs_hw.hardware_id = b.hardware_id
        AND ocs_hw.source_year = b.source_year
    LEFT JOIN (
        SELECT
            hardware_id,
            source_year,
            COUNT(*) AS total_software_count,
            SUM(CASE WHEN software_risk_level IN ('critical', 'high') THEN 1 ELSE 0 END)
                AS high_risk_software_count
        FROM {{ ref('stg_ocs_software') }}
        GROUP BY hardware_id, source_year
    ) sw_agg
        ON ocs_hw.hardware_id = sw_agg.hardware_id
        AND ocs_hw.source_year = sw_agg.source_year

),

ticket_infra AS (

    SELECT
        ticket_id,
        source_year,
        os_family,
        memory_gb,
        cpu_cores,
        memory_tier,
        bios_age_years,
        bios_risk_level,
        total_software_count,
        high_risk_software_count,
        infra_tokens
    FROM ticket_infra_raw
    WHERE rn = 1

),

-- 4. Assemble GLPI synthetic corpus
glpi_synthetic AS (

    SELECT
        MD5(CONCAT('GLPI_SIM_', t.ticket_pk)) AS similarity_pk,
        t.ticket_pk,
        'GLPI' AS source_system,
        t.ticket_id,
        t.created_at,
        t.closed_at,

        -- NLP corpus: NULL for GLPI (no real text exists)
        NULL AS text_corpus,

        -- Synthetic corpus: reconstructed from metadata + followups + infra
        CONCAT_WS(' ',
            COALESCE(t.ticket_metadata_tokens, ''),
            COALESCE(f.followup_behavior_tokens, ''),
            COALESCE(i.infra_tokens, '')
        ) AS synthetic_text_corpus,

        -- Structured encoded features (for weighted cosine similarity)
        CASE
            WHEN t.ticket_metadata_tokens LIKE '%prio_critical%' THEN 5
            WHEN t.ticket_metadata_tokens LIKE '%prio_high%' THEN 4
            WHEN t.ticket_metadata_tokens LIKE '%prio_medium%' THEN 3
            WHEN t.ticket_metadata_tokens LIKE '%prio_low%' THEN 2
            ELSE 1
        END AS priority_encoded,

        CASE
            WHEN t.ticket_metadata_tokens LIKE '%urg_critical%' THEN 5
            WHEN t.ticket_metadata_tokens LIKE '%urg_high%' THEN 4
            WHEN t.ticket_metadata_tokens LIKE '%urg_medium%' THEN 3
            WHEN t.ticket_metadata_tokens LIKE '%urg_low%' THEN 2
            ELSE 1
        END AS urgency_encoded,

        CASE
            WHEN t.ticket_metadata_tokens LIKE '%impact_critical%' THEN 5
            WHEN t.ticket_metadata_tokens LIKE '%impact_high%' THEN 4
            WHEN t.ticket_metadata_tokens LIKE '%impact_medium%' THEN 3
            WHEN t.ticket_metadata_tokens LIKE '%impact_low%' THEN 2
            ELSE 1
        END AS impact_encoded,

        CASE
            WHEN COALESCE(f.followup_count, 0) = 0 THEN 1
            WHEN f.followup_count <= 3 THEN 2
            WHEN f.followup_count <= 10 THEN 3
            WHEN f.followup_count <= 30 THEN 4
            ELSE 5
        END AS followup_count_bucket,

        -- Corpus metadata
        'synthetic_context' AS text_source_type,
        'synthetic_context' AS similarity_method,
        NULL AS embedding_model,
        'structured_metadata' AS embedding_strategy,

        -- Corpus quality score (0.0–1.0): quantifies representation trustworthiness
        CASE
            WHEN i.infra_tokens IS NOT NULL AND i.infra_tokens != ''
                THEN 0.70
            WHEN f.followup_behavior_tokens IS NOT NULL AND f.followup_behavior_tokens != ''
                THEN 0.50
            ELSE 0.30
        END AS corpus_quality_score,

        -- Similarity confidence (0.0–1.0): retrieval reliability
        CASE
            WHEN i.infra_tokens IS NOT NULL AND i.infra_tokens != ''
                THEN 0.65
            WHEN f.followup_behavior_tokens IS NOT NULL AND f.followup_behavior_tokens != ''
                THEN 0.45
            ELSE 0.25
        END AS similarity_confidence,

        -- Raw counts for downstream adjustment
        COALESCE(f.followup_count, 0) AS followup_count,
        COALESCE(f.avg_content_length, 0) AS avg_followup_content_length,
        COALESCE(f.private_ratio, 0) AS private_followup_ratio,
        COALESCE(f.url_ratio, 0) AS url_content_ratio,
        COALESCE(f.meaningful_ratio, 0) AS meaningful_content_ratio,

        -- Infrastructure context flags for quality scoring
        CASE WHEN i.os_family IS NOT NULL THEN 1 ELSE 0 END AS has_os_context,
        CASE WHEN i.memory_gb IS NOT NULL THEN 1 ELSE 0 END AS has_hardware_context,
        CASE WHEN i.bios_risk_level IS NOT NULL THEN 1 ELSE 0 END AS has_bios_context,
        CASE
            WHEN COALESCE(i.high_risk_software_count, 0) > 0 THEN 1
            ELSE 0
        END AS has_software_context

    FROM glpi_ticket_tokens t
    LEFT JOIN followup_tokens f
        ON t.ticket_id = f.ticket_id
    LEFT JOIN ticket_infra i
        ON t.ticket_id = i.ticket_id
        AND (
            (t.created_at IS NOT NULL AND EXTRACT(YEAR FROM t.created_at) = i.source_year)
            OR (t.created_at IS NULL AND i.source_year IS NULL)
        )

),

-- =============================================================================
-- KAGGLE PIPELINE: Real NLP text
-- =============================================================================

kaggle_nlp_prep AS (

    SELECT
        MD5(CONCAT('KAGGLE_SIM_', unified_ticket_pk)) AS similarity_pk,
        unified_ticket_pk,
        source_dataset AS source_system,
        COALESCE(ticket_id, '0') AS ticket_id,
        created_at,
        resolved_at AS closed_at,

        -- Real NLP text corpus
        CONCAT(
            COALESCE(NULLIF(TRIM(ticket_subject), ''), ''),
            ' ',
            COALESCE(NULLIF(TRIM(ticket_body), ''), '')
        ) AS text_corpus,

        -- No synthetic corpus needed for Kaggle
        NULL AS synthetic_text_corpus,

        -- Structured features: NULL for Kaggle (NLP-only pipeline)
        NULL AS priority_encoded,
        NULL AS urgency_encoded,
        NULL AS impact_encoded,
        NULL AS followup_count_bucket,

        -- Corpus metadata
        'real_text' AS text_source_type,
        'nlp_embedding' AS similarity_method,
        'paraphrase-multilingual-MiniLM-L12-v2' AS embedding_model,
        'nlp_semantic' AS embedding_strategy,

        -- Corpus quality: real text is higher confidence
        1.0 AS corpus_quality_score,

        -- Similarity confidence: real NLP embeddings are more reliable
        0.90 AS similarity_confidence,

        -- Fill NULL for GLPI-specific aggregation columns
        0 AS followup_count,
        0 AS avg_followup_content_length,
        0 AS private_followup_ratio,
        0 AS url_content_ratio,
        0 AS meaningful_content_ratio,

        -- Kaggle has no infrastructure context
        0 AS has_os_context,
        0 AS has_hardware_context,
        0 AS has_bios_context,
        0 AS has_software_context

    FROM {{ ref('stg_kaggle_tickets') }}

),

-- =============================================================================
-- UNIFIED OUTPUT
-- =============================================================================

unified AS (

    SELECT * FROM glpi_synthetic
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
    synthetic_text_corpus,
    similarity_method,
    embedding_strategy,
    text_source_type,
    embedding_model,
    priority_encoded,
    urgency_encoded,
    impact_encoded,
    followup_count_bucket,
    corpus_quality_score,
    similarity_confidence,
    followup_count,
    avg_followup_content_length,
    private_followup_ratio,
    url_content_ratio,
    meaningful_content_ratio,
    has_os_context,
    has_hardware_context,
    has_bios_context,
    has_software_context,
    NULL AS similar_ticket_ids,
    NULL AS similarity_scores
FROM unified