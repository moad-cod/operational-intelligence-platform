SELECT *
FROM {{ ref('int_device_performance') }}
WHERE performance_score = 3 AND performance_tier != 'high'
   OR performance_score = 2 AND performance_tier NOT IN ('medium', 'high')
   OR performance_score = 1 AND performance_tier NOT IN ('low', 'medium')