SELECT *

FROM {{ ref('stg_ocs_drives') }}

WHERE drive_pk IS NULL

   OR drive_id IS NULL

   OR hardware_id IS NULL

   OR drive_type NOT IN (
        'fixed',
        'removable',
        'usb',
        'network',
        'cdrom',
        'other'
   )

   OR storage_health NOT IN (
        'critical',
        'high',
        'medium',
        'healthy',
        'unknown'
   )

   OR source_year NOT IN (
        2013,
        2014,
        2015
   )

   OR source_system != 'OCS'