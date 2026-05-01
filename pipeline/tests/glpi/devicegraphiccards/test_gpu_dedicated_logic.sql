SELECT *
FROM {{ ref('stg_glpi_devicegraphiccards') }}
WHERE gpu_type = 'dedicated'
  AND (
        gpu_name LIKE '%Intel%'
        OR gpu_name LIKE '%XPRESS%'
      )