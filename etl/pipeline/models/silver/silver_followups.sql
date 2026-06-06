{{ config(pre_hook="SET SESSION group_concat_max_len = 100000") }}

WITH followup_agg AS (

    SELECT
        ticket_id,
        source_year,
        COUNT(*) AS followup_count,
        ROUND(AVG(content_length), 2) AS avg_followup_content_length,
        GROUP_CONCAT(
            CASE WHEN has_meaningful_content THEN content ELSE NULL END
            ORDER BY created_at ASC
            SEPARATOR ' '
        ) AS followup_text

    FROM {{ ref('stg_glpi_ticketfollowups') }}

    GROUP BY ticket_id, source_year

)

SELECT
    ticket_id,
    source_year,
    followup_count,
    avg_followup_content_length,
    COALESCE(TRIM(followup_text), '') AS followup_text

FROM followup_agg
