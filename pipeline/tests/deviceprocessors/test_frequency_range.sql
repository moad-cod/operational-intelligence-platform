SELECT *
FROM {{ ref('stg_glpi_deviceprocessors') }}
WHERE frequency_mhz IS NOT NULL
  AND (frequency_mhz < 500 OR frequency_mhz > 6000)