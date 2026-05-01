SELECT *
FROM {{ ref('stg_ocs_hardware') }}
WHERE cpu_raw LIKE '%x64%'
AND architecture = 'x86'