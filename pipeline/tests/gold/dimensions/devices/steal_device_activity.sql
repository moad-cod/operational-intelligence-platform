SELECT *
FROM {{ ref('dim_devices') }}
WHERE device_status = 'stale'
AND is_active_flag = 1