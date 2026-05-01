SELECT
    source_year,
    memory_id,
    COUNT(*) as cnt
FROM {{ ref('stg_glpi_devicememories') }}
GROUP BY source_year, memory_id
HAVING COUNT(*) > 1