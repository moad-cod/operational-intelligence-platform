SELECT *

FROM {{ ref('stg_glpi_infocoms') }}

WHERE infocom_pk IS NULL

   OR infocom_id IS NULL

   OR item_id IS NULL

   OR asset_value_tier NOT IN (
        'critical',
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