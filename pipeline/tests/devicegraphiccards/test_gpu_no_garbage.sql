SELECT *
FROM {{ ref('stg_glpi_devicegraphiccards') }}
WHERE gpu_name IS NULL