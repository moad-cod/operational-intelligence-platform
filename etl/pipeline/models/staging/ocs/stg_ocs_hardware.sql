WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_ocs_hardware') }}

),

cleaned AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', ID) AS hardware_pk,

        -- =====================================
        -- BUSINESS KEYS
        -- =====================================

        ID AS hardware_id,

        NULLIF(TRIM(DEVICEID), '') AS device_id,

        -- =====================================
        -- HOST INFORMATION
        -- =====================================

        NULLIF(TRIM(NAME), '') AS hostname,

        LOWER(TRIM(NAME)) AS normalized_hostname,

        NULLIF(TRIM(WORKGROUP), '') AS workgroup,

        NULLIF(TRIM(USERDOMAIN), '') AS user_domain,

        NULLIF(TRIM(USERID), '') AS logged_user,

        -- =====================================
        -- OPERATING SYSTEM
        -- =====================================

        NULLIF(TRIM(OSNAME), '') AS os_name,

        NULLIF(TRIM(OSVERSION), '') AS os_version,

        NULLIF(TRIM(OSCOMMENTS), '') AS os_comments,

        -- =====================================
        -- OS FAMILY DETECTION
        -- =====================================

        CASE

            WHEN LOWER(OSNAME) LIKE '%windows%'
                 THEN 'Windows'

            WHEN LOWER(OSNAME) LIKE '%linux%'
                 THEN 'Linux'

            WHEN LOWER(OSNAME) LIKE '%ubuntu%'
                 THEN 'Linux'

            WHEN LOWER(OSNAME) LIKE '%debian%'
                 THEN 'Linux'

            WHEN LOWER(OSNAME) LIKE '%mac%'
                 THEN 'MacOS'

            ELSE 'Other'

        END AS os_family,

        -- =====================================
        -- CPU
        -- =====================================

        NULLIF(TRIM(PROCESSORT), '') AS processor_type,

        PROCESSORS AS cpu_packages,

        PROCESSORN AS cpu_cores,

        -- =====================================
        -- MEMORY
        -- =====================================

        CASE

            WHEN MEMORY <= 0 THEN NULL

            ELSE ROUND(MEMORY / 1024, 2)

        END AS memory_gb,

        CASE

            WHEN SWAP <= 0 THEN NULL

            ELSE ROUND(SWAP / 1024, 2)

        END AS swap_gb,

        -- =====================================
        -- MEMORY TIER
        -- =====================================

        CASE

            WHEN MEMORY >= 16384
                 THEN 'high'

            WHEN MEMORY >= 8192
                 THEN 'medium'

            WHEN MEMORY >= 2048
                 THEN 'low'

            ELSE 'critical'

        END AS memory_tier,

        -- =====================================
        -- NETWORK
        -- =====================================

        NULLIF(TRIM(IPADDR), '') AS ip_address,

        NULLIF(TRIM(DNS), '') AS dns_name,

        NULLIF(TRIM(DEFAULTGATEWAY), '') AS default_gateway,

        NULLIF(TRIM(IPSRC), '') AS ip_source,

        -- =====================================
        -- IP VALIDATION
        -- =====================================

        CASE

            WHEN IPADDR REGEXP '^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$'
                 THEN TRUE

            ELSE FALSE

        END AS has_valid_ipv4,

        -- =====================================
        -- INVENTORY DATES
        -- =====================================

        ETIME AS inventory_time,

        LASTDATE AS last_inventory_date,

        LASTCOME AS last_seen_date,

        -- =====================================
        -- INVENTORY HEALTH
        -- =====================================

        QUALITY AS inventory_quality,

        FIDELITY AS inventory_fidelity,

        CASE

            WHEN QUALITY >= 90 THEN 'excellent'

            WHEN QUALITY >= 70 THEN 'good'

            WHEN QUALITY >= 50 THEN 'medium'

            ELSE 'poor'

        END AS inventory_quality_tier,

        -- =====================================
        -- WINDOWS INFORMATION
        -- =====================================

        NULLIF(TRIM(WINCOMPANY), '') AS windows_company,

        NULLIF(TRIM(WINOWNER), '') AS windows_owner,

        NULLIF(TRIM(WINPRODID), '') AS windows_product_id,

        CASE

            WHEN WINPRODKEY IS NULL THEN FALSE

            WHEN TRIM(WINPRODKEY) = '' THEN FALSE

            ELSE TRUE

        END AS has_windows_key,

        -- =====================================
        -- DEVICE INFORMATION
        -- =====================================

        NULLIF(TRIM(USERAGENT), '') AS user_agent,

        CHECKSUM AS inventory_checksum,

        SSTATE AS system_state,

        NULLIF(TRIM(UUID), '') AS uuid,

        UPPER(TRIM(ARCH)) AS architecture,

        -- =====================================
        -- ARCHITECTURE FAMILY
        -- =====================================

        CASE

            WHEN LOWER(ARCH) IN ('x64', 'amd64')
                 THEN '64bit'

            WHEN LOWER(ARCH) IN ('x86', 'i386')
                 THEN '32bit'

            ELSE 'unknown'

        END AS architecture_family,

        -- =====================================
        -- SECURITY FLAGS
        -- =====================================

        CASE

            WHEN UUID IS NULL THEN FALSE

            WHEN TRIM(UUID) = '' THEN FALSE

            ELSE TRUE

        END AS has_uuid,

        CASE

            WHEN USERID IS NULL THEN FALSE

            WHEN TRIM(USERID) = '' THEN FALSE

            ELSE TRUE

        END AS has_logged_user,

        -- =====================================
        -- SOURCE METADATA
        -- =====================================

        source_year,

        source_system

    FROM source

)

SELECT *

FROM cleaned