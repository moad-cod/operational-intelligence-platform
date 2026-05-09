SELECT *
FROM {{ ref('dim_users') }}
WHERE user_profile_type = 'standard_user'
AND ticket_followup_count >= 10