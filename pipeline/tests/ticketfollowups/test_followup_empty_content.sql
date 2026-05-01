SELECT *
FROM {{ ref('stg_glpi_ticketfollowups') }}
WHERE content IS NOT NULL
  AND TRIM(content) = ''