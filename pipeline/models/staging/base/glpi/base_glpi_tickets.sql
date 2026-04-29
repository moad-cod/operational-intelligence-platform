WITH tickets_2013 AS (
    SELECT *, '2013' AS year
    FROM {{ source('glpi_2013', 'glpi_tickets') }}
),

tickets_2014 AS (
    SELECT *, '2014' AS year
    FROM {{ source('glpi_2014', 'glpi_tickets') }}
),

tickets_2015 AS (
    SELECT *, '2015' AS year
    FROM {{ source('glpi_2015', 'glpi_tickets') }}
)

SELECT * FROM tickets_2013
UNION ALL

SELECT * FROM tickets_2014
UNION ALL

SELECT * FROM tickets_2015