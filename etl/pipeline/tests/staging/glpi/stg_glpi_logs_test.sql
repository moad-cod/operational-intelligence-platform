SELECT *

FROM {{ ref('stg_glpi_logs') }}

WHERE unique_id IS NULL

   OR log_id IS NULL

   OR change_type NOT IN (
        'created',
        'deleted',
        'updated',
        'no_change'
   )

   OR source_year NOT IN (
        2013,
        2014,
        2015
   )

   OR source_system != 'GLPI'