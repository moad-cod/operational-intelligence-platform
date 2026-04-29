SELECT 
    *, '2013' AS source_year
FROM 
    {{ source('glpi_2013', 'glpi_tickets') }}

UNION ALL
SELECT 
    *, '2014' AS source_year
FROM 
    {{ source('glpi_2014', 'glpi_tickets') }}

UNION ALL
SELECT 
    *, '2015' AS source_year
FROM 
    {{ source('glpi_2015', 'glpi_tickets') }}