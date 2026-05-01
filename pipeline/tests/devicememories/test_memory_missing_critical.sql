SELECT *
FROM {{ ref('stg_glpi_devicememories') }}
WHERE memory_id IS NULL
   OR memory_pk IS NULL