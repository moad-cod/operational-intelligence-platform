SELECT *
FROM {{ ref('stg_glpi_tickets') }}
WHERE
    solved_at < created_at
    OR closed_at < created_at