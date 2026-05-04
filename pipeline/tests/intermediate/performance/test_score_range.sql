SELECT *
FROM {{ ref('int_device_performance') }}
WHERE performance_score < 0
   OR performance_score > 3