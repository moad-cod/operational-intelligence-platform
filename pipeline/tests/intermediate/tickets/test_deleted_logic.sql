SELECT *
FROM {{ ref('int_ticket_features') }}
WHERE is_deleted NOT IN (0,1)