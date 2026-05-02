SELECT *
FROM {{ ref('int_ticket_features') }}
WHERE last_activity < first_activity