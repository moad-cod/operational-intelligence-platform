WITH followup_activity AS (

    SELECT
        user_id,

        COUNT(*) AS ticket_followup_count,

        MIN(created_at) AS first_activity_at,
        MAX(created_at) AS last_activity_at

    FROM {{ ref('stg_glpi_ticketfollowups') }}

    WHERE user_id IS NOT NULL
      AND TRIM(user_id) <> ''

    GROUP BY user_id

),

final AS (

    SELECT
        user_id,

        ticket_followup_count,

        first_activity_at,
        last_activity_at,

        -- User activity segmentation
        CASE
            WHEN ticket_followup_count >= 100 THEN 'very_high'
            WHEN ticket_followup_count >= 30 THEN 'high'
            WHEN ticket_followup_count >= 10 THEN 'medium'
            ELSE 'low'
        END AS user_activity_level,

        -- User business profile
        CASE
            WHEN ticket_followup_count >= 100 THEN 'power_user'
            WHEN ticket_followup_count >= 30 THEN 'support_heavy'
            WHEN ticket_followup_count >= 10 THEN 'active_user'
            ELSE 'standard_user'
        END AS user_profile_type

    FROM followup_activity

)

SELECT * FROM final