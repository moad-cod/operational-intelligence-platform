SELECT *
FROM {{ ref('stg_glpi_tickets') }}
WHERE waiting_duration < 0