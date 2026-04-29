WITH ticketfollowups_2013 AS (
    SELECT *, '2013' AS year
    FROM {{ source('glpi_2013', 'glpi_ticketfollowups') }}
),

ticketfollowups_2014 AS (
    SELECT *, '2014' AS year
    FROM {{ source('glpi_2014', 'glpi_ticketfollowups') }}
),

ticketfollowups_2015 AS (
    SELECT *, '2015' AS year
    FROM {{ source('glpi_2015', 'glpi_ticketfollowups') }}
)

SELECT * FROM ticketfollowups_2013
UNION ALL

SELECT * FROM ticketfollowups_2014
UNION ALL

SELECT * FROM ticketfollowups_2015