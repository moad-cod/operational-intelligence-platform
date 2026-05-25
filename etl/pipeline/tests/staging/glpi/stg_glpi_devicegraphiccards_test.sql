SELECT *

FROM {{ ref('stg_glpi_devicegraphiccards') }}

WHERE gpu_pk IS NULL

   OR gpu_id IS NULL

   OR gpu_name IS NULL

   OR gpu_brand NOT IN (
        'NVIDIA',
        'Intel',
        'AMD',
        'Matrox',
        'Other'
   )

   OR gpu_type NOT IN (
        'integrated',
        'dedicated',
        'virtual'
   )

   OR performance_tier NOT IN (
        'low',
        'medium',
        'high',
        'unknown',
        'virtual'
   )

   OR source_year NOT IN (
        2013,
        2014,
        2015
   )

   OR source_system != 'GLPI'