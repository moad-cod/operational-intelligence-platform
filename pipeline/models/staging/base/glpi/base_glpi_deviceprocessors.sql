WITH deviceprocessors_2013 AS (
    SELECT *, '2013' AS year
    FROM {{ source('glpi_2013', 'glpi_deviceprocessors') }}
),

deviceprocessors_2014 AS (
    SELECT *, '2014' AS year
    FROM {{ source('glpi_2014', 'glpi_deviceprocessors') }}
),

deviceprocessors_2015 AS (
    SELECT *, '2015' AS year
    FROM {{ source('glpi_2015', 'glpi_deviceprocessors') }}
)

SELECT * FROM deviceprocessors_2013
UNION ALL

SELECT * FROM deviceprocessors_2014
UNION ALL

SELECT * FROM deviceprocessors_2015