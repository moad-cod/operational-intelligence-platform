SELECT *
FROM {{ ref('stg_glpi_ticketfollowups') }}
WHERE CAST(created_at AS CHAR) = '0000-00-00 00:00:00'