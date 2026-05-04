SELECT *
FROM {{ ref('stg_ticket_features') }}
WHERE followup_count <= 0