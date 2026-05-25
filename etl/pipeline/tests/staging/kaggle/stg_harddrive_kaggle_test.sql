SELECT *

FROM {{ ref('stg_harddrive_kaggle') }}

WHERE harddrive_pk IS NULL

   OR health_status NOT IN (
        'healthy',
        'warning',
        'critical',
        'failed'
   )

   OR has_failed IS NULL

   OR has_reallocated_sectors IS NULL

   OR has_pending_sectors IS NULL

   OR has_uncorrectable_sectors IS NULL

   OR has_crc_errors IS NULL

   OR (
        capacity_gb IS NOT NULL
        AND capacity_gb < 0
   )