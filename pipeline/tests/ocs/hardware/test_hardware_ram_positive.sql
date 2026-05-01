SELECT *
FROM {{ ref('stg_ocs_hardware') }}
WHERE ram_gb < 0