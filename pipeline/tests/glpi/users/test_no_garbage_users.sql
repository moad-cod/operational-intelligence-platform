SELECT *
FROM {{ ref('stg_glpi_users') }}
WHERE LOWER(user_name) LIKE '%test%'
  AND user_type != 'TEST'