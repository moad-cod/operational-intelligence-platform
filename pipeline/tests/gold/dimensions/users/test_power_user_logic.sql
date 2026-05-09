SELECT *
FROM {{ ref('dim_users') }}
WHERE user_profile_type = 'power_user'
AND ticket_followup_count < 100