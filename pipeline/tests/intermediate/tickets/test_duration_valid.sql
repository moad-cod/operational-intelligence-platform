SELECT *
FROM {{ ref('int_ticket_features') }}
WHERE duration_days < 0