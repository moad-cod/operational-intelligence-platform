SELECT *
FROM {{ ref('stg_ticket_features') }}
WHERE is_resolved_flag = 1
  AND positive_signals = 0