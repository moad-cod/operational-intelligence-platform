WITH bios_2013 AS (
    SELECT *, '2013' AS year
    FROM {{ source('ocs_2013', 'bios') }}
),

bios_2014 AS (
    SELECT *, '2014' AS year
    FROM {{ source('ocs_2014', 'bios') }}
),

bios_2015 AS (
    SELECT *, '2015' AS year
    FROM {{ source('ocs_2015', 'bios') }}
)

SELECT * FROM bios_2013
UNION ALL

SELECT * FROM bios_2014
UNION ALL

SELECT * FROM bios_2015