SELECT *
FROM {{ ref('fct_ticket_operations') }}
WHERE sla_risk_level = 'open'
AND support_efficiency != 'unresolved'