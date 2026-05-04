SELECT *
FROM {{ ref('int_device_performance') }}
WHERE component_type = 'memory'
AND spec_1 < 0