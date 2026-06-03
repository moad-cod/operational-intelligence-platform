SELECT *

FROM {{ ref('stg_ocs_storages') }}

WHERE storage_pk IS NULL

   OR storage_id IS NULL

   OR hardware_id IS NULL

   OR storage_type NOT IN (
        'SSD',
        'NVMe',
        'HDD',
        'SATA',
        'SAS',
        'Other'
   )

   OR manufacturer_group NOT IN (
        'Seagate',
        'Western Digital',
        'Samsung',
        'Toshiba',
        'Kingston',
        'Intel',
        'Other'
   )

   OR storage_size_tier NOT IN (
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