SELECT *

FROM {{ ref('stg_ocs_software') }}

WHERE software_pk IS NULL

   OR software_id IS NULL

   OR hardware_id IS NULL

   OR architecture NOT IN (
        '64bit',
        '32bit',
        'unknown'
   )

   OR software_category NOT IN (
        'office',
        'browser',
        'security',
        'database',
        'development',
        'virtualization',
        'other'
   )

   OR software_risk_level NOT IN (
        'critical',
        'high',
        'normal'
   )

   OR source_year NOT IN (
        2013,
        2014,
        2015
   )

   OR source_system != 'OCS'