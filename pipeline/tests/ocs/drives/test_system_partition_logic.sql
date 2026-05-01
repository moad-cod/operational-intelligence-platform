{{ config(severity='warn') }}

SELECT *
FROM {{ ref('stg_ocs_drives') }}
WHERE partition_type = 'system'
  AND drive_letter <> 'C:'