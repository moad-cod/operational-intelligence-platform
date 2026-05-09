SELECT *
FROM {{ ref('fct_ticket_operations') }}
WHERE support_efficiency = 'efficient'
AND (
    positive_signals <= negative_signals
    OR solve_delay_stat >= 1000000
    OR duration_days > 7
)