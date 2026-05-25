SELECT *

FROM {{ ref('stg_glpi_deviceprocessors') }}

WHERE processor_pk IS NULL

   OR processor_id IS NULL

   OR cpu_family NOT IN (
        'i9',
        'i7',
        'i5',
        'i3',
        'Xeon',
        'Ryzen9',
        'Ryzen7',
        'Ryzen5',
        'Ryzen3',
        'Pentium',
        'Atom',
        'Core2Duo',
        'Other'
   )

   OR architecture NOT IN (
        'x64',
        'x86',
        'unknown'
   )

   OR performance_tier NOT IN (
        'high',
        'medium',
        'low',
        'unknown'
   )

   OR source_year NOT IN (
        2013,
        2014,
        2015
   )

   OR source_system != 'GLPI'