SELECT *
FROM {{ ref('stg_glpi_deviceprocessors') }}
WHERE architecture = 'x64'
  AND designation NOT LIKE '%x64%'