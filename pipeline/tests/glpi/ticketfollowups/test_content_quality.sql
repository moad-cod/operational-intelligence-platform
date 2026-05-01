SELECT *
FROM {{ ref('stg_glpi_ticketfollowups') }}
WHERE LENGTH(content) < 3