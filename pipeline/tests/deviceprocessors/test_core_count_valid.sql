SELECT *
FROM {{ ref('stg_glpi_deviceprocessors') }}
WHERE core_count IS NOT NULL
  AND core_count NOT IN (1,2,4,6)