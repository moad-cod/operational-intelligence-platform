SELECT
    source_year,
    hardware_id,
    COUNT(*) as cnt
FROM {{ ref('stg_ocs_bios') }}
GROUP BY source_year, hardware_id
HAVING COUNT(*) > 1