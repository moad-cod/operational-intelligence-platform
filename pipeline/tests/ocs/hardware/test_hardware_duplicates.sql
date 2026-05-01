{{ config(severity='warn') }}

SELECT
    device_name,
    source_year,
    COUNT(*) as cnt
FROM {{ ref('stg_ocs_hardware') }}
GROUP BY device_name, source_year
HAVING COUNT(*) > 1