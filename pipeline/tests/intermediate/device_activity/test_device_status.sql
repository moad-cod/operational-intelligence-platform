SELECT *
FROM {{ ref('int_device_activity') }}
WHERE 
    (days_since_last_seen <= 7 AND device_status != 'active')
 OR (days_since_last_seen > 7 AND days_since_last_seen <= 30 AND device_status != 'inactive')
 OR (days_since_last_seen > 30 AND device_status != 'stale')