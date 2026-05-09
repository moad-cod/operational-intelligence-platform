SELECT *
FROM {{ ref('dim_users') }}
WHERE ticket_followup_count < 0