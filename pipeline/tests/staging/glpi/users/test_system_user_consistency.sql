SELECT *
FROM {{ ref('stg_glpi_users') }}
WHERE user_type = 'SYSTEM'
  AND user_name NOT LIKE '%$%'
  AND LOWER(user_name) NOT IN ('glpi','post-only','tech','normal','administrateur')