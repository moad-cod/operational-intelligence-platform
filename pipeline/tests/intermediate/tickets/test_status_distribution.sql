SELECT status, COUNT(*)
FROM {{ ref('int_ticket_features') }}
GROUP BY status
HAVING COUNT(*) = 0