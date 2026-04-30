SELECT
    source_year,
    ticket_id,
    COUNT(*) as cnt
FROM {{ ref('stg_glpi_tickets') }}
GROUP BY source_year, ticket_id
HAVING COUNT(*) > 1