SELECT *
FROM {{ ref('fct_ticket_operations') }}
WHERE support_efficiency = 'unresolved'
AND is_resolved_flag != 0