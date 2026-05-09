SELECT *
FROM {{ ref('dim_users') }}
WHERE user_activity_level = 'very_high'
AND ticket_followup_count < 100