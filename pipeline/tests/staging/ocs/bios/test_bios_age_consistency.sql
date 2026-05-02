SELECT *
FROM {{ ref('stg_ocs_bios') }}
WHERE bios_age_years IS NOT NULL
  AND bios_age_years < 0