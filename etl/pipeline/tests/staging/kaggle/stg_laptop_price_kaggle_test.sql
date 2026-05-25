SELECT *

FROM {{ ref('stg_laptop_price_kaggle') }}

WHERE laptop_pk IS NULL

   OR has_ips_panel IS NULL

   OR has_touchscreen IS NULL

   OR has_ssd IS NULL

   OR has_hdd IS NULL

   OR cpu_family NOT IN (
        'i7',
        'i5',
        'i3',
        'ryzen7',
        'ryzen5',
        'celeron',
        'other'
   )

   OR gpu_brand NOT IN (
        'NVIDIA',
        'AMD',
        'Intel',
        'Other'
   )

   OR price_segment NOT IN (
        'premium',
        'mid_range',
        'budget',
        'unknown'
   )

   OR (
        price_euros IS NOT NULL
        AND price_euros < 0
   )