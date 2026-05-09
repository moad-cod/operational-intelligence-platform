SELECT *
FROM {{ ref('fct_ticket_operations') }}
WHERE ticket_complexity_level = 'high'
AND followup_count < 20
AND negative_signals < 10
AND duration_days < 30
AND solve_delay_stat < 5000000