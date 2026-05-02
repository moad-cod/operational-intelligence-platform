SELECT *
FROM {{ ref('int_device_storage') }}
WHERE total_storage_gb < 0
   OR avg_usage_ratio < 0
   OR avg_usage_ratio > 1