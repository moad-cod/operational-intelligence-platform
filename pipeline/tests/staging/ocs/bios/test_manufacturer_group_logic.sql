SELECT *
FROM {{ ref('stg_ocs_bios') }}
WHERE manufacturer_group = 'HP'
  AND system_manufacturer NOT LIKE '%Hewlett%'
  AND system_manufacturer NOT LIKE '%Compaq%'