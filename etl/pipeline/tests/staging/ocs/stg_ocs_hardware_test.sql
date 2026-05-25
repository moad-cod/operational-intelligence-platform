SELECT *

FROM {{ ref('stg_ocs_hardware') }}

WHERE hardware_pk IS NULL

   OR hardware_id IS NULL

   OR os_family NOT IN (
        'Windows',
        'Linux',
        'MacOS',
        'Other'
   )

   OR memory_tier NOT IN (
        'high',
        'medium',
        'low',
        'critical'
   )

   OR inventory_quality_tier NOT IN (
        'excellent',
        'good',
        'medium',
        'poor'
   )

   OR architecture_family NOT IN (
        '64bit',
        '32bit',
        'unknown'
   )

   OR source_year NOT IN (
        2013,
        2014,
        2015
   )

   OR source_system != 'OCS'