WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_ocs_software') }}

),

base AS (

    SELECT

        -- =====================================
        -- SURROGATE PRIMARY KEY
        -- =====================================

        MD5(
            CONCAT(
                source_year,
                '_',
                HARDWARE_ID,
                '_',
                ID,
                '_',
                IFNULL(NAME, ''),
                '_',
                IFNULL(VERSION, '')
            )
        ) AS software_pk,

        ID AS software_id,

        HARDWARE_ID AS hardware_id,

        NULLIF(TRIM(PUBLISHER), '') AS publisher,

        NULLIF(TRIM(NAME), '') AS software_name,

        LOWER(TRIM(NAME)) AS normalized_software_name,

        NULLIF(TRIM(VERSION), '') AS software_version,

        NULLIF(TRIM(FOLDER), '') AS install_folder,

        NULLIF(TRIM(COMMENTS), '') AS comments,

        NULLIF(TRIM(FILENAME), '') AS executable_name,

        CASE
            WHEN FILESIZE IS NULL THEN NULL
            WHEN FILESIZE <= 0 THEN NULL
            ELSE ROUND(FILESIZE / 1024, 2)
        END AS filesize_mb,

        SOURCE AS software_source,

        NULLIF(TRIM(GUID), '') AS software_guid,

        NULLIF(TRIM(LANGUAGE), '') AS software_language,

        CASE
            WHEN INSTALLDATE IS NULL THEN NULL
            ELSE INSTALLDATE
        END AS install_date,

        CASE
            WHEN BITSWIDTH = 64 THEN '64bit'
            WHEN BITSWIDTH = 32 THEN '32bit'
            ELSE 'unknown'
        END AS architecture,

        CASE

            WHEN LOWER(NAME) LIKE '%office%'
                 THEN 'office'

            WHEN LOWER(NAME) LIKE '%chrome%'
                 OR LOWER(NAME) LIKE '%firefox%'
                 OR LOWER(NAME) LIKE '%edge%'
                 THEN 'browser'

            WHEN LOWER(NAME) LIKE '%antivirus%'
                 OR LOWER(NAME) LIKE '%security%'
                 OR LOWER(NAME) LIKE '%defender%'
                 THEN 'security'

            WHEN LOWER(NAME) LIKE '%sql%'
                 OR LOWER(NAME) LIKE '%mysql%'
                 OR LOWER(NAME) LIKE '%postgres%'
                 THEN 'database'

            WHEN LOWER(NAME) LIKE '%java%'
                 OR LOWER(NAME) LIKE '%python%'
                 OR LOWER(NAME) LIKE '%visual studio%'
                 THEN 'development'

            WHEN LOWER(NAME) LIKE '%vmware%'
                 OR LOWER(NAME) LIKE '%virtualbox%'
                 THEN 'virtualization'

            ELSE 'other'

        END AS software_category,

        CASE
            WHEN GUID IS NULL THEN FALSE
            WHEN TRIM(GUID) = '' THEN FALSE
            ELSE TRUE
        END AS has_guid,

        CASE
            WHEN VERSION IS NULL THEN FALSE
            WHEN TRIM(VERSION) = '' THEN FALSE
            ELSE TRUE
        END AS has_version,

        CASE
            WHEN INSTALLDATE IS NULL THEN FALSE
            ELSE TRUE
        END AS has_install_date,

        CASE
            WHEN LOWER(NAME) LIKE '%java 6%'
                 THEN 'high'

            WHEN LOWER(NAME) LIKE '%flash%'
                 THEN 'high'

            WHEN LOWER(NAME) LIKE '%xp%'
                 THEN 'critical'

            ELSE 'normal'

        END AS software_risk_level,

        source_year,

        source_system

    FROM source

),

deduplicated AS (

    SELECT DISTINCT *

    FROM base

)

SELECT *

FROM deduplicated