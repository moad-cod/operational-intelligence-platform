SELECT *

FROM {{ ref('stg_glpi_itilcategories') }}

WHERE itil_category_pk IS NULL

   OR category_id IS NULL

   OR category_type NOT IN (
        'NETWORK',
        'HARDWARE',
        'SOFTWARE',
        'SECURITY',
        'PRINTER',
        'MAIL',
        'VPN',
        'OTHER'
   )

   OR category_complexity NOT IN (
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