SELECT *
FROM {{ ref('stg_ocs_bios') }}
WHERE bios_date IS NOT NULL
  AND bios_date > CURRENT_DATE