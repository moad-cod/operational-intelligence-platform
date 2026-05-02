SELECT *
FROM {{ ref('stg_glpi_devicememories') }}
WHERE designation LIKE '%No ECC%'
  AND is_ecc != 0