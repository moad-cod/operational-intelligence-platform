SELECT *
FROM {{ ref('int_device_activity') }}
WHERE 
    (days_since_last_seen <= 2 AND activity_score != 3)
 OR (days_since_last_seen > 2 AND days_since_last_seen <= 7 AND activity_score != 2)
 OR (days_since_last_seen > 7 AND activity_score != 1)