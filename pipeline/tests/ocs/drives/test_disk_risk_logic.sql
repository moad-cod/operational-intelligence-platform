SELECT *
FROM {{ ref('stg_ocs_drives') }}
WHERE disk_risk_level = 'critical'
  AND usage_ratio < 0.9