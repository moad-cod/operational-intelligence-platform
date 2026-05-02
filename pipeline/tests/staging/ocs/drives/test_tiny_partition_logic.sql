SELECT *
FROM {{ ref('stg_ocs_drives') }}
WHERE is_tiny_partition = 1
  AND total_gb >= 1