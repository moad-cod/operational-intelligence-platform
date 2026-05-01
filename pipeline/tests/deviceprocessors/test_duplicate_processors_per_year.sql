SELECT
    source_year,
    processor_id,
    COUNT(*) as cnt
FROM {{ ref('stg_glpi_deviceprocessors') }}
GROUP BY source_year, processor_id
HAVING COUNT(*) > 1