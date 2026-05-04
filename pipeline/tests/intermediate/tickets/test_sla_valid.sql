SELECT *
FROM {{ ref('int_ticket_features') }}
WHERE close_delay_stat < 0
   OR solve_delay_stat < 0
   OR takeintoaccount_delay_stat < 0