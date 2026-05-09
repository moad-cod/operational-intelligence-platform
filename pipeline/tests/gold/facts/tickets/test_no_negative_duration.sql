SELECT *
FROM {{ ref('fct_ticket_operations') }}
WHERE duration_days < 0