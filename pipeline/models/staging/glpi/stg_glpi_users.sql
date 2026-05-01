SELECT
    CONCAT(year, '_', id) AS user_pk,

    id AS user_id,

    -- Clean username
    CASE 
        WHEN name IS NULL THEN NULL
        WHEN TRIM(name) = '' THEN NULL
        ELSE TRIM(name)
    END AS user_name,

    -- Clean names
    NULLIF(TRIM(firstname), '') AS first_name,
    NULLIF(TRIM(realname), '') AS last_name,

    -- Directory
    NULLIF(TRIM(user_dn), '') AS user_dn,

    -- Token
    NULLIF(TRIM(personal_token), '') AS personal_token,

    CASE 
        WHEN personal_token_date IS NULL THEN NULL
        WHEN CAST(personal_token_date AS CHAR) = '0000-00-00 00:00:00' THEN NULL
        ELSE personal_token_date
    END AS personal_token_date,

    -- 🔥 system flag
    CASE 
        WHEN name LIKE '%$%' THEN 1
        WHEN LOWER(name) IN ('glpi','post-only','tech','normal','administrateur') THEN 1
        ELSE 0
    END AS is_system_user,

    year AS source_year

FROM {{ ref('base_glpi_users') }}