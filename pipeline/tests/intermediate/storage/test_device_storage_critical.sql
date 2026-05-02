SELECT *
FROM {{ ref('int_device_storage') }}
WHERE max_usage_ratio >= 0.9
AND critical_disk_flag = 0