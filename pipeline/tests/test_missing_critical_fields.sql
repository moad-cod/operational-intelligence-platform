SELECT *
FROM {{ ref('stg_glpi_tickets') }}
WHERE
    created_at IS NULL
    OR ticket_id IS NULL