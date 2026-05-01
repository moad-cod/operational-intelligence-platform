SELECT device_status, COUNT(*)
FROM {{ ref('stg_ocs_hardware') }}
GROUP BY device_status
HAVING COUNT(*) = 0