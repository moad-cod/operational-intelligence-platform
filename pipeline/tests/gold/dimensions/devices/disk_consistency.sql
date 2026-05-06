SELECT *
FROM {{ ref('dim_devices') }}
WHERE critical_disk_flag = 1
AND storage_risk_level NOT IN ('high', 'critical')