SELECT *
FROM {{ ref('glpi_ticket_features') }}
WHERE last_activity < first_activity