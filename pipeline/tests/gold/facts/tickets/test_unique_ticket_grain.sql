SELECT
    ticket_id,
    COUNT(*) AS duplicate_count

FROM {{ ref('fct_ticket_operations') }}

GROUP BY ticket_id

HAVING COUNT(*) > 1