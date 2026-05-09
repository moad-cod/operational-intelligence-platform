SELECT *
FROM {{ ref('fct_ticket_operations') }}
WHERE LOWER(status) IN ('closed', 'solved')
AND is_resolved_flag != 1