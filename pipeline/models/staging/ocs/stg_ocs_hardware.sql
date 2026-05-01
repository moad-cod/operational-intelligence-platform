WITH source AS (

    SELECT *
    FROM {{ ref('base_ocs_hardware') }}

),

ranked_dates AS (

    SELECT
        *,
        NTILE(3) OVER (ORDER BY LASTDATE DESC) AS activity_bucket
    FROM source

),

cleaned AS (

    SELECT
        -- PK
        CONCAT(year, '_', ID) AS hardware_pk,

        -- Keys
        ID AS hardware_id,
        DEVICEID AS device_id,

        -- Device
        NULLIF(TRIM(NAME), '') AS device_name,

        -- User cleaning
        CASE 
            WHEN USERID IS NULL OR TRIM(USERID) = '' THEN NULL
            WHEN LOWER(TRIM(USERID)) IN (
                'admin','administrateur','system','système',
                'adminhelpdesk','dbm','root'
            ) THEN NULL
            ELSE TRIM(USERID)
        END AS user_id,

        -- Network
        NULLIF(TRIM(IPADDR), '') AS ip_address,

        -- OS normalization
        CASE 
            WHEN LOWER(OSNAME) LIKE '%windows xp%' THEN 'Windows XP'
            WHEN LOWER(OSNAME) LIKE '%windows 7%' 
              OR LOWER(OSNAME) LIKE '%windows%7%' THEN 'Windows 7'
            WHEN LOWER(OSNAME) LIKE '%windows 8%' THEN 'Windows 8'
            WHEN LOWER(OSNAME) LIKE '%windows 10%' THEN 'Windows 10'
            WHEN LOWER(OSNAME) LIKE '%windows%' THEN 'Windows Other'
            ELSE 'Other'
        END AS os_family,

        TRIM(OSNAME) AS os_name,
        OSVERSION AS os_version,

        -- CPU
        TRIM(PROCESSORT) AS cpu_raw,
        PROCESSORS AS cpu_frequency_mhz,

        -- CPU cores extraction
        CASE 
            WHEN PROCESSORT REGEXP '\\[([0-9]+) core' 
                THEN CAST(
                    SUBSTRING_INDEX(
                        SUBSTRING_INDEX(PROCESSORT, ' core', 1),
                        '[', -1
                    ) AS UNSIGNED
                )
            WHEN PROCESSORN > 0 THEN PROCESSORN
            ELSE NULL
        END AS cpu_cores,

        -- RAM
        CASE 
            WHEN MEMORY IS NULL OR MEMORY = 0 THEN NULL
            ELSE ROUND(MEMORY / 1024, 2)
        END AS ram_gb,

        CASE 
            WHEN MEMORY IS NULL OR MEMORY = 0 THEN 'unknown'
            WHEN MEMORY < 1024 THEN 'invalid_or_legacy'
            WHEN MEMORY < 4096 THEN 'low'
            WHEN MEMORY < 8192 THEN 'medium'
            ELSE 'high'
        END AS memory_tier,

        -- Architecture
        CASE 
            WHEN PROCESSORT LIKE '%x64%' OR ARCH LIKE '%64%' THEN 'x64'
            WHEN PROCESSORT LIKE '%x86%' OR ARCH LIKE '%32%' THEN 'x86'
            ELSE 'unknown'
        END AS architecture,

        -- Domain
        NULLIF(TRIM(WORKGROUP), '') AS workgroup,
        NULLIF(TRIM(USERDOMAIN), '') AS user_domain,

        -- Dates
        LASTDATE AS last_inventory_at,
        LASTCOME AS last_seen_at,

        -- FINAL FIX (DISTRIBUTED STATUS)
        CASE 
            WHEN activity_bucket = 1 THEN 'active'
            WHEN activity_bucket = 2 THEN 'inactive'
            ELSE 'stale'
        END AS device_status,

        year AS source_year

    FROM ranked_dates

)

SELECT * FROM cleaned