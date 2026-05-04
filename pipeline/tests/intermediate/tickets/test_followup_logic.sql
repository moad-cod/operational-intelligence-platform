SELECT *
FROM {{ ref('int_ticket_features') }}
WHERE followup_count = 0
AND (
    positive_signals > 0
    OR negative_signals > 0
    OR duration_days > 0
)