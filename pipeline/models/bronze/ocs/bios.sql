SELECT 
    *, '2013' AS source_year
FROM 
    {{ source('ocs_2013', 'bios') }}

UNION ALL
SELECT 
    *, '2014' AS source_year
FROM 
    {{ source('ocs_2014', 'bios') }}

UNION ALL
SELECT 
    *, '2015' AS source_year
FROM 
    {{ source('ocs_2015', 'bios') }}
ORDER BY
    HARDWARE_ID, source_year