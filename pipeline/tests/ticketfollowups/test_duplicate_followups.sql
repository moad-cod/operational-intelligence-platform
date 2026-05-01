SELECT
    source_year,
    followup_id,
    COUNT(*) AS cnt
FROM {{ ref('stg_glpi_ticketfollowups') }}
GROUP BY source_year, followup_id
HAVING COUNT(*) > 1