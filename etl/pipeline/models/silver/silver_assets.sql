/*
  silver_assets.sql
  ─────────────────────────────────────────────────────────────────────────────
  PURPOSE
  ───────
  Produce a unified asset view combining OCS hardware inventory, BIOS
  firmware metadata, GLPI financial data, ITIL categories, ticket incident
  history, drive/disk health, and software risk profile.

  All features are aligned to a shared schema so that a downstream ML
  model can score GLPI/OCS assets for failure risk.

  Kaggle SMART hard-drive data is handled in a separate model
  (silver_harddrive_facts) to avoid MySQL performance bottlenecks
  from 1.3M-row window functions.

  FEATURES
  ────────
  • asset_age_years        — buy_date from infocoms (fallback: BIOS date)
  • bios_risk_encoded      — BIOS firmware age ordinal (0–3)
  • drive_health_encoded   — MAX(ordinal) across all fixed drives
  • storage_capacity_gb    — SUM of fixed drive sizes
  • drive_count            — COUNT of fixed drives
  • memory_gb / cpu_cores  — from OCS hardware
  • high_risk_software_count / risk_software_ratio / software_installed_count
  • incident_count         — all tickets linked to this Computer
  • hardware_incident_count— type=1 (incident) tickets on this Computer
  • glpi_failure_proxy     — 1 if asset shows hardware failure evidence
  • days_since_last_inventory / has_warranty

  No heuristic risk scores — those belong in the gold layer.
  ─────────────────────────────────────────────────────────────────────────────
*/

WITH ocs_base AS (

    SELECT
        hardware_pk                                                         AS asset_pk,
        hardware_id,
        COALESCE(normalized_hostname, CONCAT('unknown-', hardware_id))      AS asset_name,
        uuid,
        cpu_cores,
        memory_gb,
        last_inventory_date,
        last_seen_date,
        source_year,
        source_system
    FROM {{ ref('stg_ocs_hardware') }}

),

bios_enrich AS (

    SELECT
        hardware_id,
        source_year,
        system_manufacturer,
        system_model,
        serial_number,
        device_type,
        bios_age_years,
        CASE bios_risk_level
            WHEN 'critical' THEN 3
            WHEN 'high'     THEN 2
            WHEN 'medium'   THEN 1
            WHEN 'low'      THEN 0
            ELSE NULL
        END                                                                 AS bios_risk_encoded
    FROM {{ ref('stg_ocs_bios') }}

),

glpi_computers AS (

    SELECT
        computer_id,
        computer_uuid,
        computer_name,
        source_year
    FROM {{ ref('stg_glpi_computers') }}
    WHERE is_template = FALSE AND is_deleted = FALSE

),

infocoms AS (

    SELECT
        item_id,
        has_warranty,
        warranty_date,
        buy_date
    FROM {{ ref('stg_glpi_infocoms') }}
    WHERE item_type = 'Computer'

),

hardware_incidents AS (

    SELECT
        items_id AS computer_id,
        COUNT(DISTINCT ticket_id)       AS hardware_incident_count,
        COUNT(DISTINCT CASE
            WHEN priority >= 4 THEN ticket_id
        END)                            AS critical_hardware_incidents
    FROM {{ ref('stg_glpi_tickets') }}
    WHERE is_incident = TRUE
      AND item_type = 'Computer'
      AND items_id IS NOT NULL
    GROUP BY items_id

),

glpi_all_tickets AS (

    SELECT
        items_id AS computer_id,
        COUNT(DISTINCT ticket_id)       AS incident_count
    FROM {{ ref('stg_glpi_tickets') }}
    WHERE item_type = 'Computer'
      AND items_id IS NOT NULL
    GROUP BY items_id

),

component_drives AS (

    SELECT
        source_year,
        hardware_id,
        COUNT(DISTINCT drive_pk)                    AS drive_count,
        ROUND(SUM(COALESCE(total_size_gb, 0)), 2)  AS storage_capacity_gb,
        MAX(
            CASE storage_health
                WHEN 'critical' THEN 3
                WHEN 'high'     THEN 2
                WHEN 'medium'   THEN 1
                WHEN 'good'     THEN 0
                ELSE NULL
            END
        )                                           AS drive_health_encoded
    FROM {{ ref('stg_ocs_drives') }}
    WHERE drive_type = 'fixed'
    GROUP BY source_year, hardware_id

),

ocs_software_risk AS (

    SELECT
        source_year,
        hardware_id,
        COUNT(*)                                                            AS software_installed_count,
        COUNT(CASE WHEN software_risk_level IN ('critical', 'high') THEN 1 END)
                                                                            AS high_risk_software_count,
        ROUND(
            COUNT(CASE WHEN software_risk_level IN ('critical', 'high') THEN 1 END)
            / NULLIF(COUNT(*), 0),
        4)                                                                  AS risk_software_ratio
    FROM {{ ref('stg_ocs_software') }}
    GROUP BY source_year, hardware_id

),

glpi_ocs_joined AS (

    SELECT
        o.asset_pk,
        o.asset_name,
        'ocs_glpi'                                                          AS source_domain,

        b.system_manufacturer,
        b.system_model,
        b.serial_number,
        b.device_type,
        o.uuid,
        o.source_year,
        o.last_inventory_date,
        o.last_seen_date,

        COALESCE(
            CASE
                WHEN i.buy_date IS NOT NULL
                    THEN TIMESTAMPDIFF(YEAR, i.buy_date, CURRENT_DATE)
                ELSE NULL
            END,
            b.bios_age_years,
            0
        )                                                                   AS asset_age_years,
        b.bios_risk_encoded,
        COALESCE(d.drive_health_encoded, 0)                                 AS drive_health_encoded,
        COALESCE(d.storage_capacity_gb, 0)                                  AS storage_capacity_gb,
        COALESCE(d.drive_count, 0)                                          AS drive_count,
        COALESCE(o.memory_gb, 0)                                            AS memory_gb,
        COALESCE(o.cpu_cores, 0)                                            AS cpu_cores,
        COALESCE(sw.high_risk_software_count, 0)                            AS high_risk_software_count,
        COALESCE(sw.risk_software_ratio, 0)                                 AS risk_software_ratio,
        COALESCE(sw.software_installed_count, 0)                            AS software_installed_count,
        COALESCE(ic.incident_count, 0)                                      AS incident_count,
        COALESCE(hi.hardware_incident_count, 0)                             AS hardware_incident_count,
        COALESCE(
            TIMESTAMPDIFF(DAY, o.last_seen_date, CURRENT_DATE),
            TIMESTAMPDIFF(DAY, o.last_inventory_date, CURRENT_DATE),
            -1
        )                                                                   AS days_since_last_inventory,
        COALESCE(i.has_warranty, FALSE)                                     AS has_warranty,

        -- ── GLPI FAILURE PROXY ───────────────────────────────────────────
        -- Defensible proxy: an asset shows hardware failure evidence if:
        --   1. At least 3 hardware incidents (escalating pattern)
        --   2. OR at least 1 critical/urgent hardware incident (prio >= 4)
        --   3. OR at least 2 hardware incidents total (repeat issue pattern)
        CASE
            WHEN hi.hardware_incident_count >= 3 THEN 1
            WHEN hi.critical_hardware_incidents >= 1 THEN 1
            WHEN hi.hardware_incident_count >= 2 THEN 1
            ELSE 0
        END                                                                 AS glpi_failure_proxy,

        ROW_NUMBER() OVER (
            PARTITION BY COALESCE(o.uuid, o.asset_name)
            ORDER BY o.last_inventory_date DESC
        )                                                                   AS rn

    FROM ocs_base o
    LEFT JOIN bios_enrich b
        ON  o.source_year = b.source_year
        AND o.hardware_id = b.hardware_id
    LEFT JOIN glpi_computers g
        ON  (o.uuid IS NOT NULL AND o.uuid != '' AND o.uuid = g.computer_uuid)
        OR  (o.asset_name = g.computer_name AND o.source_year = g.source_year)
    LEFT JOIN infocoms i
        ON  g.computer_id = i.item_id
    LEFT JOIN hardware_incidents hi
        ON  g.computer_id = hi.computer_id
    LEFT JOIN glpi_all_tickets ic
        ON  g.computer_id = ic.computer_id
    LEFT JOIN component_drives d
        ON  o.source_year = d.source_year
        AND o.hardware_id = d.hardware_id
    LEFT JOIN ocs_software_risk sw
        ON  o.source_year = sw.source_year
        AND o.hardware_id = sw.hardware_id

)

SELECT
    asset_pk, asset_name, source_domain,
    system_manufacturer, system_model, serial_number, device_type,
    uuid, source_year, last_inventory_date, last_seen_date,
    asset_age_years, bios_risk_encoded, drive_health_encoded,
    storage_capacity_gb, drive_count, memory_gb, cpu_cores,
    high_risk_software_count, risk_software_ratio, software_installed_count,
    incident_count, hardware_incident_count,
    days_since_last_inventory, has_warranty,
    glpi_failure_proxy
FROM glpi_ocs_joined
WHERE rn = 1
