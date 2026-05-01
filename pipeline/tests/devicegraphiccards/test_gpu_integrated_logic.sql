SELECT *
FROM {{ ref('stg_glpi_devicegraphiccards') }}
WHERE gpu_type = 'integrated'
  AND gpu_name NOT LIKE '%Intel%'
  AND gpu_name NOT LIKE '%XPRESS%'
  AND gpu_name NOT LIKE '%Express Chipset%'