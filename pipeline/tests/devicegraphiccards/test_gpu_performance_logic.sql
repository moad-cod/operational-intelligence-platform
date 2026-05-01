SELECT *
FROM {{ ref('stg_glpi_devicegraphiccards') }}
WHERE gpu_type = 'integrated'
  AND vram_gb >= 2
  AND performance_tier != 'medium'