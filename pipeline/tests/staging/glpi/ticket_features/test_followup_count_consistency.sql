WITH base AS (
    SELECT
        ticket_id,
        COUNT(*) AS real_count
    FROM {{ ref('stg_glpi_ticketfollowups') }}
    GROUP BY ticket_id
)

SELECT f.*
FROM {{ ref('stg_ticket_features') }} f
JOIN base b
    ON f.ticket_id = b.ticket_id
WHERE f.followup_count != b.real_count