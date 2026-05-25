SELECT *

FROM {{ ref('stg_ocs_memories') }}

WHERE memory_pk IS NULL

   OR memory_id IS NULL

   OR hardware_id IS NULL

   OR memory_type NOT IN (
        'DDR5',
        'DDR4',
        'DDR3',
        'DDR2',
        'DDR',
        'SDRAM',
        'Other'
   )

   OR performance_tier NOT IN (
        'high',
        'medium',
        'low',
        'unknown'
   )

   OR memory_size_tier NOT IN (
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

   OR source_system != 'OCS'