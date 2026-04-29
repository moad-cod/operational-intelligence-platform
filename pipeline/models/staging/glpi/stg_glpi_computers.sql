SELECT
    id AS computer_id,
    uuid AS computer_uuid,
    name AS computer_name,

    CASE WHEN is_template = 1 THEN TRUE ELSE FALSE END AS is_template,
    CASE WHEN is_deleted = 1 THEN TRUE ELSE FALSE END AS is_deleted,
    CASE WHEN is_ocs_import = 1 THEN TRUE ELSE FALSE END AS is_ocs_import,

    manufacturers_id,
    users_id,
    groups_id,

    year AS source_year,

    CASE
        WHEN is_template = 1 THEN 'template'
        ELSE 'real_machine'
    END AS computer_type

FROM {{ ref('base_glpi_computers') }}