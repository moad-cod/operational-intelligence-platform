SELECT *
FROM {{ ref('stg_glpi_devicegraphiccards') }}
WHERE gpu_brand = 'NVIDIA'
  AND gpu_name NOT LIKE '%NVIDIA%'
  AND gpu_name NOT LIKE '%GeForce%'
  AND gpu_name NOT LIKE '%Quadro%'