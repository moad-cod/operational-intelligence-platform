SELECT *
FROM {{ ref('int_ticket_features') }}
WHERE positive_signals < 0
   OR negative_signals < 0