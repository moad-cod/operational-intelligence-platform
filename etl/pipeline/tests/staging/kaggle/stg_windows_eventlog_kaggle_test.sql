SELECT *

FROM {{ ref('stg_windows_eventlog_kaggle') }}

WHERE eventlog_pk IS NULL

   OR severity_level NOT IN (
        'critical',
        'warning',
        'high',
        'audit',
        'informational'
   )

   OR suspicious_activity IS NULL

   OR is_error_event IS NULL

   OR is_warning_event IS NULL

   OR event_domain NOT IN (
        'security',
        'system',
        'application',
        'network',
        'other'
   )