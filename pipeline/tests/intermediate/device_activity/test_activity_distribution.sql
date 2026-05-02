SELECT device_status, COUNT(*)
FROM {{ ref('int_device_activity') }}
GROUP BY device_status
HAVING COUNT(*) = 0