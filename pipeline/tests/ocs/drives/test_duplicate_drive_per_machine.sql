SELECT
    source_year,
    hardware_id,
    drive_letter,
    COUNT(*) as cnt
FROM {{ ref('stg_ocs_drives') }}
GROUP BY source_year, hardware_id, drive_letter
HAVING COUNT(*) > 1