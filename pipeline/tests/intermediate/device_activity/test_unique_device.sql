SELECT hardware_id, COUNT(*)
FROM {{ ref('int_device_activity') }}
GROUP BY hardware_id
HAVING COUNT(*) > 1