SELECT *
FROM {{ ref('int_device_performance') }}
WHERE component_type = 'gpu'
AND performance_score = 0