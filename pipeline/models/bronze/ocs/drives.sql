SELECT 
    *, '2013' AS source_year
FROM 
    {{ source('ocs_2013', 'drives') }}

UNION ALL
SELECT 
    *, '2014' AS source_year
FROM 
    {{ source('ocs_2014', 'drives') }}

UNION ALL
SELECT 
    *, '2015' AS source_year
FROM 
    {{ source('ocs_2015', 'drives') }}