SELECT *
FROM {{ ref('stg_ocs_hardware') }}
WHERE cpu_cores <= 0