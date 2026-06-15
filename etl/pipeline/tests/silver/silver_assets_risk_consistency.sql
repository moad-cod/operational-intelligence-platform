-- Asset risk score consistency: high drive_health or bios_risk should not be low risk
SELECT asset_pk, asset_name, asset_age_years, bios_risk_encoded, drive_health_encoded
FROM {{ ref('silver_assets') }}
WHERE source_domain = 'ocs_glpi'
  AND (
    (drive_health_encoded >= 3 AND bios_risk_encoded IS NULL)
    OR (bios_risk_encoded >= 3 AND drive_health_encoded = 0 AND asset_age_years < 2)
  )
