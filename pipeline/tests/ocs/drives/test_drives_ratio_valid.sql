SELECT *
FROM {{ ref('stg_ocs_drives') }}
WHERE usage_ratio < 0
   OR usage_ratio > 1