SELECT *
FROM {{ ref('stg_ocs_bios') }}
WHERE bios_version LIKE '%;%'