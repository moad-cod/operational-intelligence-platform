WITH hardware_2013 AS (
    SELECT *, '2013' AS year
    FROM {{ source('ocs_2013', 'hardware') }}
),

hardware_2014 AS (
    SELECT *, '2014' AS year
    FROM {{ source('ocs_2014', 'hardware') }}
),

hardware_2015 AS (
    SELECT *, '2015' AS year
    FROM {{ source('ocs_2015', 'hardware') }}
)

SELECT * FROM hardware_2013
UNION ALL

SELECT * FROM hardware_2014
UNION ALL

SELECT * FROM hardware_2015