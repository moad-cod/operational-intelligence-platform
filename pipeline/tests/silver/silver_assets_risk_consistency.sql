-- Asset risk score definitions should be consistent
SELECT asset_pk, asset_risk_score, bios_risk_level, high_risk_software_count
FROM {{ ref('silver_assets') }}
WHERE
    (bios_risk_level = 'critical' AND asset_risk_score != 'critical')
    OR (bios_risk_level = 'high' AND device_age_years >= 10 AND asset_risk_score != 'high')
    OR (bios_risk_level = 'medium' AND asset_risk_score = 'low')
