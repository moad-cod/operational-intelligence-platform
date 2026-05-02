SELECT *
FROM {{ ref('stg_ocs_drives') }}
WHERE drive_type IN ('cdrom','removable')
  AND total_gb IS NOT NULL