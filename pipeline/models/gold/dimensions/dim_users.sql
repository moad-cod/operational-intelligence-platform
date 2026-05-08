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

device_activity AS (

    SELECT
        user_id,

        COUNT(DISTINCT hardware_id) AS managed_device_count

    FROM {{ ref('stg_ocs_hardware') }}

    WHERE user_id IS NOT NULL
      AND TRIM(user_id) <> ''

    GROUP BY user_id

),

combined AS (

    SELECT
        f.user_id,

        -- Ticket metrics
        COALESCE(f.ticket_followup_count, 0) AS ticket_followup_count,

        f.first_activity_at,
        f.last_activity_at,

        -- Device metrics
        COALESCE(d.managed_device_count, 0) AS managed_device_count

    FROM followup_activity f

    LEFT JOIN device_activity d
        ON f.user_id = d.user_id

),

final AS (

    SELECT
        user_id,

        ticket_followup_count,
        managed_device_count,

        first_activity_at,
        last_activity_at,

        -- User activity segmentation
        CASE
            WHEN ticket_followup_count >= 100 THEN 'very_high'
            WHEN ticket_followup_count >= 30 THEN 'high'
            WHEN ticket_followup_count >= 10 THEN 'medium'
            ELSE 'low'
        END AS user_activity_level,

        -- Operational scope
        CASE
            WHEN managed_device_count >= 20 THEN 'critical'
            WHEN managed_device_count >= 10 THEN 'important'
            WHEN managed_device_count >= 3 THEN 'standard'
            ELSE 'limited'
        END AS user_operational_scope,

        -- Business profile
        CASE
            WHEN ticket_followup_count >= 100
                 AND managed_device_count >= 10 THEN 'power_user'

            WHEN managed_device_count >= 20 THEN 'infra_manager'

            WHEN ticket_followup_count >= 30 THEN 'support_heavy'

            ELSE 'standard_user'
        END AS user_profile_type

    FROM combined

)

SELECT * FROM final