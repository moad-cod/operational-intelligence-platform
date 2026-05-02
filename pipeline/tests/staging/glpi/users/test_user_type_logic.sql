SELECT *
FROM {{ ref('stg_glpi_users') }}
WHERE user_type = 'HUMAN'
  AND (
        user_name LIKE '%$%'
        OR LOWER(user_name) IN ('glpi','post-only','tech','normal','administrateur')
)