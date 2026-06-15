-- Gold model: gold_asset_failure_risk
-- Source: silver_assets (single dependency — no staging joins, no bronze refs)
-- All feature engineering lives in silver_assets; this layer adds:
--   1. rule_based_risk_score (heuristic baseline for ML comparison)
--   2. risk_explanation (human-readable why this asset scored how it did)
--   3. prioritization tier (for triage)
--   4. anomaly_score + is_anomaly (populated by Python Isolation Forest)
-- Materialized: table

WITH risk_scored AS (

    SELECT
        asset_pk,
        asset_name,
        source_domain,
        source_year,

        -- ── Core risk features (passthrough from silver) ──────────────
        asset_age_years,
        bios_risk_encoded,
        drive_health_encoded,
        storage_capacity_gb,
        drive_count,
        memory_gb,
        cpu_cores,
        high_risk_software_count,
        risk_software_ratio,
        software_installed_count,
        incident_count,
        hardware_incident_count,
        days_since_last_inventory,
        has_warranty,
        glpi_failure_proxy,

        -- ── Device metadata for explainability ────────────────────────
        system_manufacturer,
        system_model,
        device_type,

        -- ── Heuristic baseline risk score ─────────────────────────────
        -- Sum of component risk levels, each 1-4 scale
        -- Total range: 5-20 (higher = riskier)
        COALESCE(
            CASE
                WHEN asset_age_years >= 10 THEN 4
                WHEN asset_age_years >= 5  THEN 3
                WHEN asset_age_years >= 2  THEN 2
                ELSE 1
            END, 1
        )
        +
        COALESCE(
            CASE
                WHEN high_risk_software_count > 5 THEN 4
                WHEN high_risk_software_count > 2 THEN 3
                WHEN high_risk_software_count > 0 THEN 2
                ELSE 1
            END, 1
        )
        +
        COALESCE(
            CASE
                WHEN drive_health_encoded >= 3 THEN 4
                WHEN drive_health_encoded = 2  THEN 3
                WHEN drive_health_encoded = 1  THEN 2
                ELSE 1
            END, 1
        )
        +
        COALESCE(
            CASE
                WHEN bios_risk_encoded >= 3 THEN 4
                WHEN bios_risk_encoded = 2  THEN 3
                WHEN bios_risk_encoded = 1  THEN 2
                ELSE 1
            END, 1
        )
        +
        COALESCE(
            CASE
                WHEN days_since_last_inventory >= 180 THEN 4
                WHEN days_since_last_inventory >= 60  THEN 3
                WHEN days_since_last_inventory >= 30  THEN 2
                ELSE 1
            END, 1
        )                                                           AS rule_based_risk_score,

        -- ── Risk tier (business-friendly categorization) ──────────────
        -- Uses inline calculation instead of referencing rule_based_risk_score alias
        CASE
            WHEN glpi_failure_proxy = 1 THEN 'high'
            WHEN incident_count >= 5     THEN 'high'
            WHEN (
                COALESCE(CASE WHEN asset_age_years >= 10 THEN 4 WHEN asset_age_years >= 5 THEN 3 WHEN asset_age_years >= 2 THEN 2 ELSE 1 END, 1)
                + COALESCE(CASE WHEN high_risk_software_count > 5 THEN 4 WHEN high_risk_software_count > 2 THEN 3 WHEN high_risk_software_count > 0 THEN 2 ELSE 1 END, 1)
                + COALESCE(CASE WHEN drive_health_encoded >= 3 THEN 4 WHEN drive_health_encoded = 2 THEN 3 WHEN drive_health_encoded = 1 THEN 2 ELSE 1 END, 1)
                + COALESCE(CASE WHEN bios_risk_encoded >= 3 THEN 4 WHEN bios_risk_encoded = 2 THEN 3 WHEN bios_risk_encoded = 1 THEN 2 ELSE 1 END, 1)
                + COALESCE(CASE WHEN days_since_last_inventory >= 180 THEN 4 WHEN days_since_last_inventory >= 60 THEN 3 WHEN days_since_last_inventory >= 30 THEN 2 ELSE 1 END, 1)
            ) >= 18 THEN 'high'
            WHEN (
                COALESCE(CASE WHEN asset_age_years >= 10 THEN 4 WHEN asset_age_years >= 5 THEN 3 WHEN asset_age_years >= 2 THEN 2 ELSE 1 END, 1)
                + COALESCE(CASE WHEN high_risk_software_count > 5 THEN 4 WHEN high_risk_software_count > 2 THEN 3 WHEN high_risk_software_count > 0 THEN 2 ELSE 1 END, 1)
                + COALESCE(CASE WHEN drive_health_encoded >= 3 THEN 4 WHEN drive_health_encoded = 2 THEN 3 WHEN drive_health_encoded = 1 THEN 2 ELSE 1 END, 1)
                + COALESCE(CASE WHEN bios_risk_encoded >= 3 THEN 4 WHEN bios_risk_encoded = 2 THEN 3 WHEN bios_risk_encoded = 1 THEN 2 ELSE 1 END, 1)
                + COALESCE(CASE WHEN days_since_last_inventory >= 180 THEN 4 WHEN days_since_last_inventory >= 60 THEN 3 WHEN days_since_last_inventory >= 30 THEN 2 ELSE 1 END, 1)
            ) >= 13 THEN 'medium'
            WHEN (
                COALESCE(CASE WHEN asset_age_years >= 10 THEN 4 WHEN asset_age_years >= 5 THEN 3 WHEN asset_age_years >= 2 THEN 2 ELSE 1 END, 1)
                + COALESCE(CASE WHEN high_risk_software_count > 5 THEN 4 WHEN high_risk_software_count > 2 THEN 3 WHEN high_risk_software_count > 0 THEN 2 ELSE 1 END, 1)
                + COALESCE(CASE WHEN drive_health_encoded >= 3 THEN 4 WHEN drive_health_encoded = 2 THEN 3 WHEN drive_health_encoded = 1 THEN 2 ELSE 1 END, 1)
                + COALESCE(CASE WHEN bios_risk_encoded >= 3 THEN 4 WHEN bios_risk_encoded = 2 THEN 3 WHEN bios_risk_encoded = 1 THEN 2 ELSE 1 END, 1)
                + COALESCE(CASE WHEN days_since_last_inventory >= 180 THEN 4 WHEN days_since_last_inventory >= 60 THEN 3 WHEN days_since_last_inventory >= 30 THEN 2 ELSE 1 END, 1)
            ) >= 9 THEN 'low'
            ELSE 'info'
        END                                                         AS risk_tier,

        -- ── Explainability: why is this asset risky? ───────────────────
        CONCAT_WS('; ',
            CASE
                WHEN asset_age_years >= 10
                    THEN CONCAT('old_asset:', asset_age_years, 'yrs')
                ELSE NULL
            END,
            CASE
                WHEN drive_health_encoded >= 3 THEN 'drive_health_critical'
                WHEN drive_health_encoded = 2  THEN 'drive_health_degraded'
                ELSE NULL
            END,
            CASE
                WHEN high_risk_software_count > 5
                    THEN CONCAT('risky_software:', high_risk_software_count)
                WHEN high_risk_software_count > 2
                    THEN CONCAT('risky_software:', high_risk_software_count)
                ELSE NULL
            END,
            CASE
                WHEN bios_risk_encoded >= 3 THEN 'bios_outdated'
                ELSE NULL
            END,
            CASE
                WHEN days_since_last_inventory >= 180
                    THEN CONCAT('stale_inventory:', days_since_last_inventory, 'days')
                ELSE NULL
            END,
            CASE
                WHEN glpi_failure_proxy = 1 THEN 'hardware_failure_evidence'
                ELSE NULL
            END,
            CASE
                WHEN hardware_incident_count >= 3
                    THEN CONCAT('repeat_hw_incidents:', hardware_incident_count)
                WHEN hardware_incident_count >= 1
                    THEN CONCAT('hw_incidents:', hardware_incident_count)
                ELSE NULL
            END
        )                                                           AS risk_explanation,

        -- ── ML slots (populated by Python) ─────────────────────────────
        CAST(NULL AS DOUBLE)                                        AS anomaly_score,
        CAST(NULL AS SIGNED)                                        AS is_anomaly

    FROM {{ ref('silver_assets') }}
    WHERE source_domain = 'ocs_glpi'

)

SELECT
    asset_pk,
    asset_name,
    source_domain,
    source_year,
    -- core features
    asset_age_years,
    bios_risk_encoded,
    drive_health_encoded,
    storage_capacity_gb,
    drive_count,
    memory_gb,
    cpu_cores,
    high_risk_software_count,
    risk_software_ratio,
    software_installed_count,
    incident_count,
    hardware_incident_count,
    days_since_last_inventory,
    has_warranty,
    glpi_failure_proxy,
    -- metadata
    system_manufacturer,
    system_model,
    device_type,
    -- explainability
    rule_based_risk_score,
    risk_tier,
    risk_explanation,
    -- ML output
    anomaly_score,
    is_anomaly
FROM risk_scored
