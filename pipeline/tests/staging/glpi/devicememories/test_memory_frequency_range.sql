SELECT *
FROM {{ ref('stg_glpi_devicememories') }}
WHERE frequency_mhz IS NOT NULL
  AND (frequency_mhz < 200 OR frequency_mhz > 4000)