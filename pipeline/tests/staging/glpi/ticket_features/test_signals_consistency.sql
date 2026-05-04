SELECT *
FROM {{ ref('stg_ticket_features') }}
WHERE positive_signals < 0
   OR negative_signals < 0