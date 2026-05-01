SELECT *
FROM {{ ref('stg_ocs_hardware') }}
WHERE device_name IS NULL