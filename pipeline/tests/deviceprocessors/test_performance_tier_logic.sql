SELECT *
FROM {{ ref('stg_glpi_deviceprocessors') }}
WHERE performance_tier = 'high'
  AND cpu_family NOT IN ('i7','Xeon')