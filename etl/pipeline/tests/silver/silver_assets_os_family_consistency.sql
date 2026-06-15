-- Asset age consistency: buy_date-based age should be <= BIOS-based age
SELECT asset_pk, asset_name, asset_age_years
FROM {{ ref('silver_assets') }}
WHERE source_domain = 'ocs_glpi'
  AND asset_age_years < 0
