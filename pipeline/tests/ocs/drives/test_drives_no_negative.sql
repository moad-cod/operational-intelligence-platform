SELECT *
FROM {{ ref('stg_ocs_drives') }}
WHERE total_gb < 0
   OR free_gb < 0
   OR used_gb < 0