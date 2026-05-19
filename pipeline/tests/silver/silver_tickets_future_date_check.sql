-- No future created_at dates (allow up to 1 day clock skew)
SELECT event_pk
FROM {{ ref('silver_tickets') }}
WHERE created_at > DATE_ADD(CURRENT_DATE, INTERVAL 1 DAY)
