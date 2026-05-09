SELECT *
FROM {{ ref('fct_ticket_operations') }}
WHERE ticket_complexity_level = 'medium'
AND followup_count < 8
AND negative_signals < 4
AND duration_days < 7
AND solve_delay_stat < 1000000