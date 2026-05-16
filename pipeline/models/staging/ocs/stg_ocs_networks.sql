WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_ocs_networks') }}

),

base AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', ID) AS network_pk,

        -- =====================================
        -- BUSINESS KEYS
        -- =====================================

        ID AS network_id,

        HARDWARE_ID AS hardware_id,

        -- =====================================
        -- NETWORK DESCRIPTION
        -- =====================================

        NULLIF(TRIM(DESCRIPTION), '') AS network_description,

        -- =====================================
        -- NETWORK TYPE
        -- =====================================

        CASE

            WHEN LOWER(TYPE) LIKE '%ethernet%'
                 THEN 'ethernet'

            WHEN LOWER(TYPE) LIKE '%wifi%'
                 THEN 'wifi'

            WHEN LOWER(TYPE) LIKE '%wireless%'
                 THEN 'wifi'

            WHEN LOWER(TYPE) LIKE '%bluetooth%'
                 THEN 'bluetooth'

            WHEN LOWER(TYPE) LIKE '%loopback%'
                 THEN 'loopback'

            WHEN LOWER(TYPE) LIKE '%vpn%'
                 THEN 'vpn'

            ELSE 'other'

        END AS network_type,

        NULLIF(TRIM(TYPEMIB), '') AS network_mib,

        -- =====================================
        -- NETWORK SPEED
        -- =====================================

        CASE

            WHEN SPEED IS NULL THEN NULL

            WHEN TRIM(SPEED) = '' THEN NULL

            WHEN CAST(SPEED AS UNSIGNED) = 0
                 THEN NULL

            ELSE ROUND(
                CAST(SPEED AS UNSIGNED) / 1000000,
                2
            )

        END AS speed_mbps,

        -- =====================================
        -- SPEED TIER
        -- =====================================

        CASE

            WHEN CAST(SPEED AS UNSIGNED) >= 1000000000
                 THEN 'high'

            WHEN CAST(SPEED AS UNSIGNED) >= 100000000
                 THEN 'medium'

            WHEN CAST(SPEED AS UNSIGNED) > 0
                 THEN 'low'

            ELSE 'unknown'

        END AS speed_tier,

        -- =====================================
        -- MAC ADDRESS
        -- =====================================

        CASE

            WHEN MACADDR IS NULL THEN NULL

            WHEN TRIM(MACADDR) = '' THEN NULL

            ELSE UPPER(TRIM(MACADDR))

        END AS mac_address,

        -- =====================================
        -- CONNECTION STATUS
        -- =====================================

        CASE

            WHEN LOWER(STATUS) IN (
                'up',
                'connected',
                'active'
            ) THEN 'active'

            WHEN LOWER(STATUS) IN (
                'down',
                'disconnected',
                'inactive'
            ) THEN 'inactive'

            ELSE 'unknown'

        END AS connection_status,

        -- =====================================
        -- IP INFORMATION
        -- =====================================

        NULLIF(TRIM(IPADDRESS), '') AS ip_address,

        NULLIF(TRIM(IPMASK), '') AS ip_mask,

        NULLIF(TRIM(IPGATEWAY), '') AS ip_gateway,

        NULLIF(TRIM(IPSUBNET), '') AS ip_subnet,

        NULLIF(TRIM(IPDHCP), '') AS dhcp_server,

        -- =====================================
        -- IP VALIDATION
        -- =====================================

        CASE

            WHEN IPADDRESS REGEXP
                 '^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$'
                 THEN TRUE

            ELSE FALSE

        END AS has_valid_ipv4,

        -- =====================================
        -- DHCP FLAG
        -- =====================================

        CASE

            WHEN IPDHCP IS NULL THEN FALSE

            WHEN TRIM(IPDHCP) = '' THEN FALSE

            ELSE TRUE

        END AS uses_dhcp,

        -- =====================================
        -- VIRTUAL DEVICE
        -- =====================================

        CASE

            WHEN VIRTUALDEV = 1 THEN TRUE

            ELSE FALSE

        END AS is_virtual_device,

        -- =====================================
        -- NETWORK SECURITY FLAGS
        -- =====================================

        CASE

            WHEN MACADDR IS NULL THEN FALSE

            WHEN TRIM(MACADDR) = '' THEN FALSE

            ELSE TRUE

        END AS has_mac_address,

        -- =====================================
        -- SOURCE METADATA
        -- =====================================

        source_year,

        source_system

    FROM source

)

SELECT *

FROM base