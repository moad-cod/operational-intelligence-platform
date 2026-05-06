SELECT *
FROM {{ ref('dim_devices') }}
WHERE avg_usage_ratio < 0
   OR avg_usage_ratio > 1