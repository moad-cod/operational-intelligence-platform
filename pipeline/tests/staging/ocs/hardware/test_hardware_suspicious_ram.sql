SELECT *
FROM {{ ref('stg_ocs_hardware') }}
WHERE ram_gb < 1
AND memory_tier != 'invalid_or_legacy'