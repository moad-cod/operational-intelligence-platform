SELECT *
FROM {{ ref('stg_glpi_tickets') }}
WHERE is_deleted NOT IN (0, 1)