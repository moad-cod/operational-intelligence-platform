SELECT ticket_id, COUNT(*)
FROM {{ ref('int_ticket_features') }}
GROUP BY ticket_id
HAVING COUNT(*) > 1