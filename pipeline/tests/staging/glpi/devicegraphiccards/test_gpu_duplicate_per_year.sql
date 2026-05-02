SELECT
    source_year,
    gpu_id,
    COUNT(*) as cnt
FROM {{ ref('stg_glpi_devicegraphiccards') }}
GROUP BY source_year, gpu_id
HAVING COUNT(*) > 1