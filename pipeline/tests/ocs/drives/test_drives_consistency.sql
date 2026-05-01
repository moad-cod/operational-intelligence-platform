SELECT *
FROM {{ ref('stg_ocs_drives') }}
WHERE total_gb IS NOT NULL
  AND free_gb IS NOT NULL
  AND ABS((total_gb - free_gb) - used_gb) > 0.1