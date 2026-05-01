SELECT *
FROM {{ ref('stg_ocs_hardware') }}
WHERE os_family = 'Windows 7'
AND LOWER(os_name) NOT REGEXP 'windows.*7'