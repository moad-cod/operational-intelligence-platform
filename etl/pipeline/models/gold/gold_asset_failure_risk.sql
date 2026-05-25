-- Gold model: gold_asset_failure_risk
-- Sources: stg_ocs_hardware, stg_ocs_bios, stg_ocs_drives, stg_ocs_storages,
--          stg_ocs_software, stg_glpi_computers, stg_glpi_infocoms, stg_glpi_tickets
-- Consumers: Isolation Forest anomaly detector
-- Materialized: table

WITH ocs_hw AS (

    SELECT
        hardware_pk,
        hardware_id,
        COALESCE(normalized_hostname, CONCAT('host-', hardware_id)) AS asset_name,
        memory_gb,
        cpu_cores,
        has_valid_ipv4,
        last_inventory_date,
        last_seen_date,
        inventory_quality_tier,
        uuid,
        has_uuid,
        os_family,
        source_year
    FROM {{ ref('stg_ocs_hardware') }}

),

ocs_bios AS (

    SELECT
        hardware_id,
        source_year,
        bios_age_years,
        bios_risk_level
    FROM {{ ref('stg_ocs_bios') }}

),

ocs_drives_agg AS (

    SELECT
        hardware_id,
        source_year,
        COUNT(*) AS drive_count,
        ROUND(SUM(COALESCE(total_size_gb, 0)), 2) AS total_drive_gb,
        MIN(storage_health) AS worst_drive_health
    FROM {{ ref('stg_ocs_drives') }}
    GROUP BY hardware_id, source_year

),

ocs_storages_agg AS (

    SELECT
        hardware_id,
        source_year,
        COUNT(*) AS storage_device_count,
        ROUND(SUM(COALESCE(disk_size_gb, 0)), 2) AS total_storage_gb,
        MAX(performance_tier) AS max_storage_performance
    FROM {{ ref('stg_ocs_storages') }}
    GROUP BY hardware_id, source_year

),

ocs_software_agg AS (

    SELECT
        hardware_id,
        source_year,
        COUNT(*) AS total_software_count,
        SUM(CASE WHEN software_risk_level IN ('critical', 'high') THEN 1 ELSE 0 END) AS high_risk_software_count,
        COUNT(DISTINCT software_category) AS unique_software_categories
    FROM {{ ref('stg_ocs_software') }}
    GROUP BY hardware_id, source_year

),

glpi_computers AS (

    SELECT
        computer_id,
        computer_uuid,
        computer_name,
        manufacturers_id,
        source_year
    FROM {{ ref('stg_glpi_computers') }}
    WHERE is_template = FALSE AND is_deleted = FALSE

),

glpi_infocoms AS (

    SELECT
        item_id,
        ROUND(COALESCE(asset_value, 0), 2) AS asset_value,
        CASE WHEN has_warranty THEN 1 ELSE 0 END AS has_warranty,
        asset_value_tier
    FROM {{ ref('stg_glpi_infocoms') }}
    WHERE item_type = 'Computer'

),

glpi_ticket_incidents AS (

    SELECT
        items_id AS computer_ref,
        COUNT(*) AS incident_count
    FROM {{ source('bronze', 'bronze_glpi_tickets') }}
    WHERE is_deleted = 0 AND items_id IS NOT NULL AND items_id > 0
    GROUP BY items_id

),

joined AS (

    SELECT
        ocs_hw.hardware_pk,
        ocs_hw.hardware_id,
        ocs_hw.asset_name,
        ocs_hw.uuid,

        COALESCE(b.bios_age_years, 0) AS device_age_years,

        CASE
            WHEN b.bios_risk_level = 'critical' THEN 4
            WHEN b.bios_risk_level = 'high' THEN 3
            WHEN b.bios_risk_level = 'medium' THEN 2
            WHEN b.bios_risk_level = 'low' THEN 1
            ELSE 0
        END AS bios_risk_level_encoded,

        CASE
            WHEN d.worst_drive_health = 'critical' THEN 4
            WHEN d.worst_drive_health = 'high' THEN 3
            WHEN d.worst_drive_health = 'medium' THEN 2
            WHEN d.worst_drive_health = 'healthy' THEN 1
            ELSE 0
        END AS worst_drive_health_encoded,

        COALESCE(d.total_drive_gb, 0) AS total_drive_gb,
        COALESCE(d.drive_count, 0) AS drive_count,
        COALESCE(s.storage_device_count, 0) AS storage_device_count,
        COALESCE(sw.high_risk_software_count, 0) AS high_risk_software_count,
        COALESCE(sw.total_software_count, 0) AS total_software_count,

        ROUND(
            COALESCE(sw.high_risk_software_count, 0) /
            NULLIF(COALESCE(sw.total_software_count, 0), 0)
        , 4) AS risk_software_ratio,

        COALESCE(ocs_hw.memory_gb, 0) AS memory_gb,
        COALESCE(ocs_hw.cpu_cores, 0) AS cpu_cores,
        CASE WHEN ocs_hw.has_valid_ipv4 THEN 1 ELSE 0 END AS has_valid_ipv4,
        COALESCE(i.has_warranty, 0) AS has_warranty,
        COALESCE(i.asset_value, 0) AS asset_value,
        COALESCE(inc.incident_count, 0) AS incident_count,

        CASE
            WHEN ocs_hw.last_inventory_date IS NOT NULL
            THEN DATEDIFF(CURRENT_DATE, ocs_hw.last_inventory_date)
            ELSE 365
        END AS days_since_last_inventory,

        CASE
            WHEN ocs_hw.inventory_quality_tier = 'excellent' THEN 4
            WHEN ocs_hw.inventory_quality_tier = 'good' THEN 3
            WHEN ocs_hw.inventory_quality_tier = 'medium' THEN 2
            WHEN ocs_hw.inventory_quality_tier = 'poor' THEN 1
            ELSE 0
        END AS inventory_quality_tier_encoded,

        ocs_hw.os_family,
        ocs_hw.source_year,

        ROW_NUMBER() OVER (
            PARTITION BY COALESCE(ocs_hw.uuid, ocs_hw.asset_name)
            ORDER BY ocs_hw.last_seen_date DESC
        ) AS rn

    FROM ocs_hw
    LEFT JOIN ocs_bios b
        ON ocs_hw.hardware_id = b.hardware_id AND ocs_hw.source_year = b.source_year
    LEFT JOIN ocs_drives_agg d
        ON ocs_hw.hardware_id = d.hardware_id AND ocs_hw.source_year = d.source_year
    LEFT JOIN ocs_storages_agg s
        ON ocs_hw.hardware_id = s.hardware_id AND ocs_hw.source_year = s.source_year
    LEFT JOIN ocs_software_agg sw
        ON ocs_hw.hardware_id = sw.hardware_id AND ocs_hw.source_year = sw.source_year
    LEFT JOIN glpi_computers gc
        ON (ocs_hw.uuid IS NOT NULL AND ocs_hw.uuid != '' AND ocs_hw.uuid = gc.computer_uuid)
        OR (LOWER(ocs_hw.asset_name) = LOWER(gc.computer_name) AND ocs_hw.source_year = gc.source_year)
    LEFT JOIN glpi_infocoms i
        ON gc.computer_id = i.item_id
    LEFT JOIN glpi_ticket_incidents inc
        ON gc.computer_id = inc.computer_ref

),

with_risk_score AS (

    SELECT
        hardware_pk,
        hardware_id,
        asset_name,
        uuid,
        device_age_years,
        bios_risk_level_encoded,
        worst_drive_health_encoded,
        total_drive_gb,
        drive_count,
        storage_device_count,
        high_risk_software_count,
        total_software_count,
        risk_software_ratio,
        memory_gb,
        cpu_cores,
        has_valid_ipv4,
        has_warranty,
        asset_value,
        incident_count,
        days_since_last_inventory,
        inventory_quality_tier_encoded,
        os_family,
        source_year,

        -- Heuristic baseline: keep as comparison for ML output
        CASE
            WHEN device_age_years >= 10 THEN 4
            WHEN device_age_years >= 5 THEN 3
            WHEN device_age_years >= 2 THEN 2
            ELSE 1
        END
        +
        CASE
            WHEN high_risk_software_count > 5 THEN 4
            WHEN high_risk_software_count > 2 THEN 3
            WHEN high_risk_software_count > 0 THEN 2
            ELSE 1
        END
        +
        CASE
            WHEN worst_drive_health_encoded >= 3 THEN 3
            WHEN worst_drive_health_encoded = 2 THEN 2
            ELSE 1
        END
        +
        CASE
            WHEN days_since_last_inventory >= 180 THEN 3
            WHEN days_since_last_inventory >= 60 THEN 2
            ELSE 1
        END
        AS rule_based_risk_score

    FROM joined
    WHERE rn = 1

)

SELECT
    hardware_pk,
    hardware_id,
    asset_name,
    uuid,
    device_age_years,
    bios_risk_level_encoded,
    worst_drive_health_encoded,
    total_drive_gb,
    drive_count,
    storage_device_count,
    high_risk_software_count,
    total_software_count,
    risk_software_ratio,
    memory_gb,
    cpu_cores,
    has_valid_ipv4,
    has_warranty,
    asset_value,
    incident_count,
    days_since_last_inventory,
    inventory_quality_tier_encoded,
    os_family,
    source_year,
    rule_based_risk_score,
    NULL AS anomaly_score,
    NULL AS is_anomaly
FROM with_risk_score