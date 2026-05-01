SELECT
    source_year,
    user_id,
    COUNT(*) as cnt
FROM {{ ref('stg_glpi_users') }}
GROUP BY source_year, user_id
HAVING COUNT(*) > 1