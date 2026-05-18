WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'raw_windows_eventlog_data') }}

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
                IFNULL(MachineName, ''),
                '_',
                IFNULL(TimeGenerated, '')
            )
        ) AS eventlog_pk,

        -- =====================================
        -- ORIGINAL INDEX
        -- =====================================

        `Unnamed: 0` AS original_index,

        -- =====================================
        -- MACHINE
        -- =====================================

        NULLIF(TRIM(MachineName), '') AS machine_name,

        -- =====================================
        -- EVENT INFORMATION
        -- =====================================

        LOWER(NULLIF(TRIM(Category), '')) AS event_category,

        LOWER(NULLIF(TRIM(EntryType), '')) AS entry_type,

        NULLIF(TRIM(Message), '') AS event_message,

        LOWER(NULLIF(TRIM(Source), '')) AS event_source,

        -- =====================================
        -- EVENT TIME
        -- =====================================

        CASE
            WHEN TimeGenerated IS NULL THEN NULL
            WHEN TRIM(TimeGenerated) = '' THEN NULL
            ELSE TimeGenerated
        END AS generated_at,

        -- =====================================
        -- GEOLOCATION
        -- =====================================

        LOWER(NULLIF(TRIM(country), '')) AS country,

        LOWER(NULLIF(TRIM(regionName), '')) AS region_name,

        LOWER(NULLIF(TRIM(city), '')) AS city,

        zip AS zip_code,

        NULLIF(TRIM(timezone), '') AS timezone,

        NULLIF(TRIM(isp), '') AS isp,

        -- =====================================
        -- EVENT SEVERITY
        -- =====================================

        CASE

            WHEN LOWER(EntryType) LIKE '%error%'
                 THEN 'critical'

            WHEN LOWER(EntryType) LIKE '%warning%'
                 THEN 'warning'

            WHEN LOWER(EntryType) LIKE '%failure%'
                 THEN 'high'

            WHEN LOWER(EntryType) LIKE '%audit%'
                 THEN 'audit'

            ELSE 'informational'

        END AS severity_level,

        -- =====================================
        -- SECURITY FLAGS
        -- =====================================

        CASE
            WHEN LOWER(Message) LIKE '%failed%'
                 OR LOWER(Message) LIKE '%unauthorized%'
                 OR LOWER(Message) LIKE '%denied%'
                 THEN TRUE
            ELSE FALSE
        END AS suspicious_activity,

        CASE
            WHEN LOWER(EntryType) LIKE '%error%'
                 THEN TRUE
            ELSE FALSE
        END AS is_error_event,

        CASE
            WHEN LOWER(EntryType) LIKE '%warning%'
                 THEN TRUE
            ELSE FALSE
        END AS is_warning_event,

        -- =====================================
        -- EVENT DOMAIN
        -- =====================================

        CASE

            WHEN LOWER(Source) LIKE '%security%'
                 THEN 'security'

            WHEN LOWER(Source) LIKE '%system%'
                 THEN 'system'

            WHEN LOWER(Source) LIKE '%application%'
                 THEN 'application'

            WHEN LOWER(Source) LIKE '%network%'
                 THEN 'network'

            ELSE 'other'

        END AS event_domain

    FROM source

)

SELECT DISTINCT *

FROM cleaned