SELECT *
FROM {{ ref('int_device_activity') }}
WHERE 
    (days_since_last_seen <= 7 AND is_active_flag != 1)
 OR (days_since_last_seen > 7 AND is_active_flag != 0)