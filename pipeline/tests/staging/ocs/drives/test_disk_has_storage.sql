SELECT *
FROM {{ ref('stg_ocs_drives') }}
WHERE drive_type = 'disk'
  AND total_gb IS NULL
  AND free_gb IS NOT NULL   -- only fail if inconsistent