SELECT *
FROM {{ ref('stg_glpi_tickets') }}
WHERE
    close_delay_stat < 0
    OR solve_delay_stat < 0
    OR takeintoaccount_delay_stat < 0