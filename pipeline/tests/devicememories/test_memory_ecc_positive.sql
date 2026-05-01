SELECT *
FROM {{ ref('stg_glpi_devicememories') }}
WHERE designation LIKE '%ECC%'
  AND designation NOT LIKE '%No ECC%'
  AND is_ecc != 1