SELECT *
FROM {{ ref('dim_devices') }}
WHERE total_storage_gb < 0