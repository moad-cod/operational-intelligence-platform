SELECT *
FROM {{ ref('fct_ticket_operations') }}
WHERE is_resolved_flag = 0
AND LOWER(status) IN ('closed', 'solved')