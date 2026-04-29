WITH drives_2013 AS (
    SELECT *, '2013' AS year
    FROM {{ source('ocs_2013', 'drives') }}
),

drives_2014 AS (
    SELECT *, '2014' AS year
    FROM {{ source('ocs_2014', 'drives') }}
),

drives_2015 AS (
    SELECT *, '2015' AS year
    FROM {{ source('ocs_2015', 'drives') }}
)

SELECT * FROM drives_2013
UNION ALL

SELECT * FROM drives_2014
UNION ALL

SELECT * FROM drives_2015