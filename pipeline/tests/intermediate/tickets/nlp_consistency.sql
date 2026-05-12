SELECT *
FROM {{ ref('int_ticket_features') }}

WHERE positive_signals > 0
AND is_resolved_flag != 1