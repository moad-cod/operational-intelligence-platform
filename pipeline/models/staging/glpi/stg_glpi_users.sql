WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_glpi_users') }}

),

cleaned AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', id) AS user_pk,

        -- =====================================
        -- BUSINESS KEYS
        -- =====================================

        id AS user_id,

        -- =====================================
        -- USERNAME
        -- =====================================

        CASE

            WHEN name IS NULL THEN NULL

            WHEN TRIM(name) = '' THEN NULL

            ELSE TRIM(name)

        END AS user_name,

        LOWER(TRIM(name)) AS normalized_username,

        -- =====================================
        -- PERSON NAMES
        -- =====================================

        NULLIF(TRIM(firstname), '') AS first_name,

        NULLIF(TRIM(realname), '') AS last_name,

        NULLIF(
            TRIM(
                CONCAT(
                    COALESCE(firstname, ''),
                    ' ',
                    COALESCE(realname, '')
                )
            ),
            ''
        ) AS full_name,

        -- =====================================
        -- DIRECTORY / LDAP
        -- =====================================

        NULLIF(TRIM(user_dn), '') AS user_dn,

        CASE

            WHEN user_dn IS NULL THEN FALSE

            WHEN TRIM(user_dn) = '' THEN FALSE

            ELSE TRUE

        END AS has_directory_account,

        CASE

            WHEN user_dn LIKE '%DC=%'
                 THEN TRUE

            ELSE FALSE

        END AS is_ldap_user,

        -- =====================================
        -- PERSONAL TOKEN
        -- =====================================

        NULLIF(TRIM(personal_token), '') AS personal_token,

        CASE

            WHEN personal_token IS NULL THEN FALSE

            WHEN TRIM(personal_token) = '' THEN FALSE

            ELSE TRUE

        END AS has_personal_token,

        CASE

            WHEN personal_token_date IS NULL THEN NULL

            WHEN CAST(personal_token_date AS CHAR)
                 = '0000-00-00 00:00:00'
                 THEN NULL

            ELSE CAST(personal_token_date AS DATETIME)

        END AS personal_token_date,

        -- =====================================
        -- USER TYPE CLASSIFICATION
        -- =====================================

        CASE

            WHEN name LIKE '%$%'
                 THEN 'SYSTEM'

            WHEN LOWER(name) IN (
                'glpi',
                'post-only',
                'tech',
                'normal',
                'administrateur'
            ) THEN 'SYSTEM'

            WHEN LOWER(name) IN (
                'hotlinedsic',
                'standard',
                'contact',
                'centre.documentation',
                'sgagadir',
                'waliagadir'
            ) THEN 'SERVICE'

            WHEN LOWER(name) LIKE '%test%'
                 THEN 'TEST'

            WHEN firstname IS NOT NULL
                 OR realname IS NOT NULL
                 THEN 'HUMAN'

            ELSE 'UNKNOWN'

        END AS user_type,

        -- =====================================
        -- QUALITY FLAGS
        -- =====================================

        CASE

            WHEN name IS NULL THEN FALSE

            WHEN TRIM(name) = '' THEN FALSE

            ELSE TRUE

        END AS has_username,

        CASE

            WHEN NULLIF(TRIM(firstname), '') IS NULL
                 AND NULLIF(TRIM(realname), '') IS NULL
                 THEN FALSE

            ELSE TRUE

        END AS has_real_identity,

        -- =====================================
        -- SUSPICIOUS ACCOUNTS
        -- =====================================

        CASE

            WHEN LENGTH(TRIM(name)) <= 3
                 THEN TRUE

            WHEN name NOT LIKE '%.%'
                 AND firstname IS NULL
                 AND realname IS NULL
                 THEN TRUE

            ELSE FALSE

        END AS suspicious_account,

        -- =====================================
        -- SOURCE METADATA
        -- =====================================

        source_year,

        source_system

    FROM source

)

SELECT *

FROM cleaned