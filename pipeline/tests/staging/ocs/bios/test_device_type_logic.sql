SELECT *
FROM {{ ref('stg_ocs_bios') }}
WHERE device_type = 'desktop'
  AND system_model LIKE '%Notebook%'