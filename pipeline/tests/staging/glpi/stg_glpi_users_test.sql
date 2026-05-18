SELECT *

FROM {{ ref('stg_glpi_users') }}

WHERE user_pk IS NULL

   OR user_id IS NULL

   OR user_type NOT IN (
        'SYSTEM',
        'SERVICE',
        'TEST',
        'HUMAN',
        'UNKNOWN'
   )

   OR source_year NOT IN (
        2013,
        2014,
        2015
   )

   OR source_system != 'GLPI'