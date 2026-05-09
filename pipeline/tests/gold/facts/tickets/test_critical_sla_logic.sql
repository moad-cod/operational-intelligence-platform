SELECT *
FROM {{ ref('fct_ticket_operations') }}
WHERE sla_risk_level = 'critical'
AND solve_delay_stat < 10000000
AND close_delay_stat < 15000000