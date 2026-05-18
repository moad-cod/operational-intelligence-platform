SELECT *

FROM {{ ref('stg_glpi_devicememories') }}

WHERE memory_pk IS NULL

   OR memory_id IS NULL

   OR memory_type NOT IN (
        'DDR5',
        'DDR4',
        'DDR3',
        'DDR2',
        'DDR',
        'SDRAM',
        'RDRAM',
        'Other'
   )

   OR performance_tier NOT IN (
        'high',
        'medium',
        'low',
        'unknown'
   )

   OR memory_capacity_tier NOT IN (
        'enterprise',
        'high',
        'medium',
        'low',
        'legacy'
   )

   OR source_year NOT IN (
        2013,
        2014,
        2015
   )

   OR source_system != 'GLPI'