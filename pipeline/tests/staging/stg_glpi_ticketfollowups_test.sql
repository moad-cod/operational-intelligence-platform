SELECT *

FROM {{ ref('stg_glpi_ticketfollowups') }}

WHERE ticket_followup_pk IS NULL

   OR followup_id IS NULL

   OR ticket_id IS NULL

   OR source_year NOT IN (
        2013,
        2014,
        2015
   )

   OR source_system != 'GLPI'