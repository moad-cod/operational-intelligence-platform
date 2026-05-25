WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_glpi_ticketfollowups') }}

),

cleaned AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', id) AS ticket_followup_pk,

        -- =====================================
        -- BUSINESS KEYS
        -- =====================================

        id AS followup_id,

        tickets_id AS ticket_id,

        -- =====================================
        -- DATE
        -- =====================================

        CASE

            WHEN date IS NULL THEN NULL

            WHEN CAST(date AS CHAR) = '0000-00-00 00:00:00'
                 THEN NULL

            ELSE CAST(date AS DATETIME)

        END AS created_at,

        -- =====================================
        -- DIMENSIONS
        -- =====================================

        users_id AS user_id,

        requesttypes_id AS request_type_id,

        -- =====================================
        -- CONTENT CLEANING
        -- =====================================

        CASE

            WHEN content IS NULL THEN NULL

            WHEN TRIM(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(content, '&gt;', ''),
                            '--',
                            ''
                        ),
                        '&nbsp;',
                        ''
                    ),
                    '<br />',
                    ''
                )
            ) = '' THEN NULL

            ELSE TRIM(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(content, '&gt;', ''),
                            '--',
                            ''
                        ),
                        '&nbsp;',
                        ''
                    ),
                    '<br />',
                    ''
                )
            )

        END AS content,

        -- =====================================
        -- CONTENT QUALITY FLAGS
        -- =====================================

        CASE

            WHEN content IS NULL THEN FALSE

            WHEN LENGTH(TRIM(content)) < 5 THEN FALSE

            ELSE TRUE

        END AS has_meaningful_content,

        CASE

            WHEN content LIKE '%http%'
                 THEN TRUE

            ELSE FALSE

        END AS contains_url,

        CASE

            WHEN content IS NULL THEN TRUE

            WHEN LENGTH(TRIM(content)) < 5 THEN TRUE

            ELSE FALSE

        END AS is_system_generated,

        -- =====================================
        -- PRIVACY FLAG
        -- =====================================

        CASE

            WHEN is_private = 1 THEN TRUE

            ELSE FALSE

        END AS is_private,

        -- =====================================
        -- TEXT LENGTH
        -- =====================================

        CASE

            WHEN content IS NULL THEN 0

            ELSE LENGTH(content)

        END AS content_length,

        -- =====================================
        -- SOURCE METADATA
        -- =====================================

        source_year,

        source_system

    FROM source

)

SELECT *

FROM cleaned