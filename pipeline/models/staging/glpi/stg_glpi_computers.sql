SELECT

    -- =====================================
    -- UNIQUE IDENTIFIER
    -- =====================================

    CONCAT(source_year, '_', id) AS unique_id,

    -- =====================================
    -- COMPUTER IDENTIFIERS
    -- =====================================

    id AS computer_id,

    CASE
        WHEN uuid IS NULL OR uuid = '' THEN 'unknown'
        ELSE uuid
    END AS computer_uuid,

    CASE
        WHEN uuid IS NULL OR uuid = '' THEN FALSE
        ELSE TRUE
    END AS has_uuid,

    name AS computer_name,

    -- =====================================
    -- FLAGS
    -- =====================================

    CASE
        WHEN is_template = 1 THEN TRUE
        ELSE FALSE
    END AS is_template,

    CASE
        WHEN is_deleted = 1 THEN TRUE
        ELSE FALSE
    END AS is_deleted,

    CASE
        WHEN is_ocs_import = 1 THEN TRUE
        ELSE FALSE
    END AS is_ocs_import,

    -- =====================================
    -- RELATIONS
    -- =====================================

    manufacturers_id,

    users_id,

    groups_id,

    -- =====================================
    -- METADATA
    -- =====================================

    source_year,

    source_system,

    -- =====================================
    -- BUSINESS LOGIC
    -- =====================================

    CASE
        WHEN is_template = 1 THEN 'template'
        ELSE 'real_machine'
    END AS computer_type

FROM {{ source('bronze', 'bronze_glpi_computers') }}