-- Ensure priority_score matches priority level
SELECT event_pk
FROM {{ ref('silver_tickets') }}
WHERE
    (priority = 'critical' AND priority_score != 5)
    OR (priority = 'high' AND priority_score != 4)
    OR (priority = 'medium' AND priority_score != 3)
    OR (priority = 'low' AND priority_score != 2)
    OR (priority = 'unknown' AND priority_score != 1)
