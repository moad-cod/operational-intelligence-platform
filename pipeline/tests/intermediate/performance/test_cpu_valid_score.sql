SELECT *
FROM {{ ref('int_device_performance') }}
WHERE component_type = 'cpu'
AND performance_score = 0
AND component_name != 'Other'