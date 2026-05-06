SELECT *
FROM {{ ref('dim_devices') }}
WHERE device_health_status = 'healthy'
AND storage_risk_level = 'critical'