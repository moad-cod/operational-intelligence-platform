WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'raw_cve_data') }}

),

cleaned AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        MD5(
            CONCAT(
                IFNULL(`Unnamed: 0`, ''),
                '_',
                IFNULL(pub_date, '')
            )
        ) AS cve_pk,

        -- =====================================
        -- ORIGINAL DATASET ID
        -- =====================================

        `Unnamed: 0` AS original_index,

        -- =====================================
        -- CWE INFORMATION
        -- =====================================

        CASE
            WHEN cwe_code IS NULL THEN NULL
            ELSE CAST(cwe_code AS SIGNED)
        END AS cwe_code,

        NULLIF(TRIM(cwe_name), '') AS cwe_name,

        NULLIF(TRIM(summary), '') AS cve_summary,

        -- =====================================
        -- DATES
        -- =====================================

        CASE
            WHEN pub_date IS NULL THEN NULL
            WHEN TRIM(pub_date) = '' THEN NULL
            ELSE pub_date
        END AS published_at,

        CASE
            WHEN mod_date IS NULL THEN NULL
            WHEN TRIM(mod_date) = '' THEN NULL
            ELSE mod_date
        END AS modified_at,

        -- =====================================
        -- CVSS SCORE
        -- =====================================

        CASE
            WHEN cvss IS NULL THEN NULL
            WHEN cvss < 0 THEN NULL
            WHEN cvss > 10 THEN NULL
            ELSE ROUND(cvss, 1)
        END AS cvss_score,

        -- =====================================
        -- SEVERITY CLASSIFICATION
        -- =====================================

        CASE

            WHEN cvss >= 9 THEN 'critical'

            WHEN cvss >= 7 THEN 'high'

            WHEN cvss >= 4 THEN 'medium'

            WHEN cvss > 0 THEN 'low'

            ELSE 'unknown'

        END AS severity_level,

        -- =====================================
        -- ACCESS METRICS
        -- =====================================

        LOWER(
            NULLIF(
                TRIM(access_authentication),
                ''
            )
        ) AS access_authentication,

        LOWER(
            NULLIF(
                TRIM(access_complexity),
                ''
            )
        ) AS access_complexity,

        LOWER(
            NULLIF(
                TRIM(access_vector),
                ''
            )
        ) AS access_vector,

        -- =====================================
        -- IMPACT METRICS
        -- =====================================

        LOWER(
            NULLIF(
                TRIM(impact_availability),
                ''
            )
        ) AS impact_availability,

        LOWER(
            NULLIF(
                TRIM(impact_confidentiality),
                ''
            )
        ) AS impact_confidentiality,

        LOWER(
            NULLIF(
                TRIM(impact_integrity),
                ''
            )
        ) AS impact_integrity,

        -- =====================================
        -- SECURITY FLAGS
        -- =====================================

        CASE
            WHEN LOWER(access_vector) = 'network'
                 THEN TRUE
            ELSE FALSE
        END AS is_remote_exploitable,

        CASE
            WHEN cvss >= 9
                 THEN TRUE
            ELSE FALSE
        END AS is_critical,

        CASE
            WHEN LOWER(access_complexity) = 'low'
                 THEN TRUE
            ELSE FALSE
        END AS easy_to_exploit

    FROM source

)

SELECT DISTINCT *

FROM cleaned