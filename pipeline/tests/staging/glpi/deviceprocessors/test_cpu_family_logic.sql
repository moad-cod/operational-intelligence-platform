SELECT *
FROM {{ ref('stg_glpi_deviceprocessors') }}
WHERE cpu_family = 'i7'
  AND designation NOT LIKE '%i7%'