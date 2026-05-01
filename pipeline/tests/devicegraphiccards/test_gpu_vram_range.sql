SELECT *
FROM {{ ref('stg_glpi_devicegraphiccards') }}
WHERE vram_gb IS NOT NULL
  AND (vram_gb < 0.05 OR vram_gb > 32)