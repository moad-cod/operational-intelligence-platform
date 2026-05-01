SELECT *
FROM {{ ref('stg_glpi_users') }}
WHERE user_type = 'HUMAN'
  AND (
        first_name IS NULL
        AND last_name IS NULL
      )