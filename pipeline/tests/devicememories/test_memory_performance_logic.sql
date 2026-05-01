SELECT *
FROM {{ ref('stg_glpi_devicememories') }}
WHERE memory_type = 'DDR3'
  AND performance_tier = 'low'