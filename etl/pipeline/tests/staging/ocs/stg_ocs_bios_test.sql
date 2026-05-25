SELECT *

FROM {{ ref('stg_ocs_bios') }}

WHERE bios_pk IS NULL

   OR hardware_id IS NULL

   OR device_type NOT IN (
        'desktop',
        'laptop',
        'server',
        'other'
   )

   OR manufacturer_group NOT IN (
        'HP',
        'Dell',
        'Lenovo',
        'Foxconn',
        'MSI',
        'Other'
   )

   OR bios_risk_level NOT IN (
        'critical',
        'high',
        'medium',
        'low',
        'unknown'
   )

   OR source_year NOT IN (
        2013,
        2014,
        2015
   )

   OR source_system != 'OCS'