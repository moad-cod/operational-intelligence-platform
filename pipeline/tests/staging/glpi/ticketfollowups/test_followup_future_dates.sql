SELECT *
FROM {{ ref('stg_glpi_ticketfollowups') }}
WHERE created_at > NOW()