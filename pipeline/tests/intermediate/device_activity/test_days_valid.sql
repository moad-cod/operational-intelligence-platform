SELECT *
FROM {{ ref('int_device_activity') }}
WHERE days_since_last_seen < 0