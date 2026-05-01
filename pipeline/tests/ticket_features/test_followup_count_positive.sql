SELECT *
FROM {{ ref('int_ticket_features') }}
WHERE followup_count <= 0