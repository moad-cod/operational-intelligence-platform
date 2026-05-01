SELECT *
FROM {{ ref('stg_glpi_users') }}
WHERE CAST(personal_token_date AS CHAR) = '0000-00-00 00:00:00'