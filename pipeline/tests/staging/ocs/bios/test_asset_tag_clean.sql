SELECT *
FROM {{ ref('stg_ocs_bios') }}
WHERE LOWER(asset_tag) LIKE '%no asset%'
   OR LOWER(asset_tag) LIKE '%o.e.m%'