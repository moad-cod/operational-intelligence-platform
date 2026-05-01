SELECT *
FROM {{ ref('stg_glpi_devicememories') }}
WHERE memory_size_gb IS NOT NULL
  AND memory_size_gb > 64