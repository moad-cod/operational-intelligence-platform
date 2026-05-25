SELECT *

FROM {{ ref('stg_ocs_networks') }}

WHERE network_pk IS NULL

   OR network_id IS NULL

   OR hardware_id IS NULL

   OR network_type NOT IN (
        'ethernet',
        'wifi',
        'bluetooth',
        'loopback',
        'vpn',
        'other'
   )

   OR speed_tier NOT IN (
        'high',
        'medium',
        'low',
        'unknown'
   )

   OR connection_status NOT IN (
        'active',
        'inactive',
        'unknown'
   )

   OR source_year NOT IN (
        2013,
        2014,
        2015
   )

   OR source_system != 'OCS'