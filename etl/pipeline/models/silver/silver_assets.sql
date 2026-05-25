WITH ocs_base AS (

    SELECT
        hardware_pk AS asset_pk,
        hardware_id,
        device_id,
        COALESCE(normalized_hostname, CONCAT('unknown-', hardware_id)) AS asset_name,
        hostname,
        os_name,
        os_version,
        os_family,
        os_comments,
        processor_type,
        cpu_packages,
        cpu_cores,
        memory_gb,
        swap_gb,
        memory_tier,
        ip_address,
        dns_name,
        has_valid_ipv4,
        last_inventory_date,
        last_seen_date,
        inventory_quality_tier,
        uuid,
        has_uuid,
        architecture,
        architecture_family,
        source_year,
        source_system
    FROM {{ ref('stg_ocs_hardware') }}

),

bios_enrich AS (

    SELECT
        bios_pk,
        hardware_id,
        source_year,                  
        system_manufacturer,
        system_model,
        serial_number,
        device_type,
        manufacturer_group,
        bios_age_years,
        bios_risk_level
    FROM {{ ref('stg_ocs_bios') }}

),

glpi_computers AS (

    SELECT
        unique_id AS glpi_asset_pk,
        computer_id,
        computer_uuid,
        computer_name,
        is_template,
        is_deleted,
        is_ocs_import,
        manufacturers_id,
        source_year,
        computer_type
    FROM {{ ref('stg_glpi_computers') }}
    WHERE is_template = FALSE AND is_deleted = FALSE

),

infocoms AS (

    SELECT
        infocom_pk,
        item_id,
        item_type,
        asset_value,
        warranty_value,
        buy_date,
        warranty_date,
        has_warranty,
        asset_value_tier
    FROM {{ ref('stg_glpi_infocoms') }}
    WHERE item_type = 'Computer'

),

component_cpu AS (

    SELECT
        CONCAT(source_year, '_', NULLIF(TRIM(designation), '')) AS asset_ref,
        source_year,
        designation,
        COUNT(DISTINCT processor_pk) AS cpu_count,
        GROUP_CONCAT(DISTINCT cpu_family ORDER BY cpu_family SEPARATOR ', ') AS cpu_families,
        MAX(performance_tier) AS max_cpu_tier
    FROM {{ ref('stg_glpi_deviceprocessors') }}
    GROUP BY source_year, designation

),

component_memory AS (

    SELECT
        CONCAT(source_year, '_', NULLIF(TRIM(designation), '')) AS asset_ref,
        source_year,
        designation,
        COUNT(DISTINCT memory_pk) AS memory_module_count,
        ROUND(SUM(COALESCE(memory_size_gb, 0)), 2) AS total_memory_gb,
        MAX(performance_tier) AS max_memory_tier
    FROM {{ ref('stg_glpi_devicememories') }}
    GROUP BY source_year, designation

),

component_storage AS (

    SELECT
        CONCAT(source_year, '_', hardware_id) AS asset_ref,
        source_year,
        hardware_id,
        COUNT(DISTINCT storage_pk) AS storage_device_count,
        ROUND(SUM(COALESCE(disk_size_gb, 0)), 2) AS total_storage_gb,
        GROUP_CONCAT(DISTINCT storage_type ORDER BY storage_type SEPARATOR ', ') AS storage_types,
        MAX(performance_tier) AS max_storage_tier
    FROM {{ ref('stg_ocs_storages') }}
    GROUP BY source_year, hardware_id

),

component_drives AS (

    SELECT
        CONCAT(source_year, '_', hardware_id) AS asset_ref,
        source_year,
        hardware_id,
        COUNT(DISTINCT drive_pk) AS drive_count,
        ROUND(SUM(COALESCE(total_size_gb, 0)), 2) AS total_drive_gb,
        MIN(storage_health) AS worst_drive_health
    FROM {{ ref('stg_ocs_drives') }}
    WHERE drive_type = 'fixed'
    GROUP BY source_year, hardware_id

),

ocs_software_stats AS (

    SELECT
        CONCAT(source_year, '_', hardware_id) AS asset_ref,
        source_year,
        hardware_id,
        COUNT(DISTINCT software_pk) AS software_installed_count,
        COUNT(DISTINCT CASE WHEN software_risk_level IN ('critical', 'high') THEN software_pk END) AS high_risk_software_count,
        GROUP_CONCAT(DISTINCT software_category ORDER BY software_category SEPARATOR ', ') AS software_categories
    FROM {{ ref('stg_ocs_software') }}
    GROUP BY source_year, hardware_id

),

joined AS (

    SELECT
        o.asset_pk,
        o.hardware_id,
        o.asset_name,
        o.hostname,
        COALESCE(b.system_manufacturer, 'unknown') AS manufacturer,
        COALESCE(b.system_model, 'unknown') AS model,
        COALESCE(b.serial_number, 'unknown') AS serial_number,
        COALESCE(b.manufacturer_group, 'Other') AS manufacturer_group,
        COALESCE(b.device_type, 'other') AS device_type,
        COALESCE(b.bios_age_years, 0) AS device_age_years,
        COALESCE(b.bios_risk_level, 'unknown') AS bios_risk_level,
        COALESCE(o.os_family, 'Other') AS os_family,
        COALESCE(o.os_name, 'unknown') AS os_name,
        COALESCE(o.os_version, 'unknown') AS os_version,
        o.architecture,
        o.architecture_family,
        o.processor_type,
        o.cpu_packages,
        o.cpu_cores,
        o.memory_gb,
        o.memory_tier,
        o.swap_gb,
        o.ip_address,
        o.has_valid_ipv4,
        o.last_inventory_date,
        o.last_seen_date,
        o.inventory_quality_tier,
        o.uuid,
        COALESCE(g.computer_type, 'unknown') AS asset_lifecycle_stage,
        COALESCE(i.asset_value, 0) AS asset_value,
        COALESCE(i.warranty_value, 0) AS warranty_value,
        i.buy_date,
        i.warranty_date,
        COALESCE(i.has_warranty, FALSE) AS has_warranty,
        COALESCE(i.asset_value_tier, 'unknown') AS asset_value_tier,
        s.storage_device_count,
        s.total_storage_gb,
        s.storage_types,
        s.max_storage_tier,
        d.drive_count,
        d.total_drive_gb,
        d.worst_drive_health,
        sw.software_installed_count,
        sw.high_risk_software_count,
        sw.software_categories,
        o.source_year,
        o.source_system,
        ROW_NUMBER() OVER (
            PARTITION BY COALESCE(o.uuid, o.asset_name)
            ORDER BY o.last_inventory_date DESC
        ) AS rn
    FROM ocs_base o
    LEFT JOIN bios_enrich b
        ON o.source_year = b.source_year
        AND o.hardware_id = b.hardware_id
    LEFT JOIN glpi_computers g
        ON (o.uuid IS NOT NULL AND o.uuid != '' AND o.uuid = g.computer_uuid)
        OR (o.asset_name = g.computer_name AND o.source_year = g.source_year)
    LEFT JOIN infocoms i
        ON g.computer_id = i.item_id
    LEFT JOIN component_storage s
        ON o.source_year = s.source_year
        AND o.hardware_id = s.hardware_id
    LEFT JOIN component_drives d
        ON o.source_year = d.source_year
        AND o.hardware_id = d.hardware_id
    LEFT JOIN ocs_software_stats sw
        ON o.source_year = sw.source_year
        AND o.hardware_id = sw.hardware_id

),

final AS (

    SELECT
        asset_pk,
        hardware_id,
        asset_name,
        hostname,
        manufacturer,
        model,
        serial_number,
        manufacturer_group,
        device_type,
        device_age_years,
        bios_risk_level,
        os_family,
        os_name,
        os_version,
        architecture,
        architecture_family,
        processor_type,
        cpu_packages,
        cpu_cores,
        memory_gb,
        memory_tier,
        swap_gb,
        ip_address,
        has_valid_ipv4,
        last_inventory_date,
        last_seen_date,
        inventory_quality_tier,
        uuid,
        asset_lifecycle_stage,
        asset_value,
        warranty_value,
        buy_date,
        warranty_date,
        has_warranty,
        asset_value_tier,
        COALESCE(storage_device_count, 0) AS storage_device_count,
        COALESCE(total_storage_gb, 0) AS total_storage_gb,
        storage_types,
        COALESCE(drive_count, 0) AS drive_count,
        COALESCE(total_drive_gb, 0) AS total_drive_gb,
        worst_drive_health,
        COALESCE(software_installed_count, 0) AS software_installed_count,
        COALESCE(high_risk_software_count, 0) AS high_risk_software_count,
        software_categories,
        source_year,
        source_system,

        CASE
            WHEN bios_risk_level = 'critical' OR high_risk_software_count > 5 THEN 'critical'
            WHEN bios_risk_level = 'high' OR device_age_years >= 10 OR high_risk_software_count > 2 THEN 'high'
            WHEN bios_risk_level = 'medium' OR worst_drive_health IN ('critical', 'high') THEN 'medium'
            ELSE 'low'
        END AS asset_risk_score,

        CASE
            WHEN last_seen_date IS NULL
                OR TIMESTAMPDIFF(MONTH, last_seen_date, CURRENT_DATE) >= 6
                THEN 'inactive'
            WHEN TIMESTAMPDIFF(MONTH, last_seen_date, CURRENT_DATE) >= 2 THEN 'idle'
            ELSE 'active'
        END AS asset_health_status

    FROM joined
    WHERE rn = 1

)

SELECT * FROM final