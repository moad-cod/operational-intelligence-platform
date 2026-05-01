SELECT *
FROM {{ ref('stg_glpi_ticketfollowups') }}
WHERE request_type_id < 0