SELECT
    ticket_id,

    COUNT(*) AS followup_count,

    MIN(created_at) AS first_activity,
    MAX(created_at) AS last_activity,

    DATEDIFF(MAX(created_at), MIN(created_at)) AS duration_days,

    -- Positive signals
    SUM(
        CASE 
            WHEN LOWER(content) LIKE '% ok %'
              OR LOWER(content) LIKE 'ok %'
              OR LOWER(content) LIKE '% ok'
              OR LOWER(content) = 'ok'
              OR LOWER(content) LIKE '%résolu%'
              OR LOWER(content) LIKE '%resolu%'
              OR LOWER(content) LIKE '%solution%'
            THEN 1 
            ELSE 0 
        END
    ) AS positive_signals,

    -- ❌ Negative signals
    SUM(
        CASE 
            WHEN LOWER(content) LIKE '%nok%'
              OR LOWER(content) LIKE '%probleme%'
              OR LOWER(content) LIKE '%erreur%'
            THEN 1 
            ELSE 0 
        END
    ) AS negative_signals,

    -- Final flag
    CASE 
        WHEN MAX(
            CASE 
                WHEN LOWER(content) LIKE '%résolu%' 
                  OR LOWER(content) LIKE '%resolu%'
                  OR LOWER(content) LIKE '% ok %'
                  OR LOWER(content) = 'ok'
                THEN 1 
                ELSE 0 
            END
        ) = 1 
        THEN 1
        ELSE 0
    END AS is_resolved_flag

FROM {{ ref('stg_glpi_ticketfollowups') }}

GROUP BY ticket_id
