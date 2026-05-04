WITH cpu AS (

    SELECT
        processor_pk AS component_id,
        'cpu' AS component_type,

        cpu_family AS component_name,
        COALESCE(core_count, 1) AS spec_1,
        frequency_mhz AS spec_2,
        NULL AS spec_3,

        CASE 
            WHEN performance_tier = 'high' THEN 3
            WHEN performance_tier = 'medium' THEN 2
            WHEN performance_tier = 'low' THEN 1
            ELSE 0
        END AS performance_score,

        performance_tier,
        source_year

    FROM {{ ref('stg_glpi_deviceprocessors') }}

),

memory AS (

    SELECT
        memory_pk AS component_id,
        'memory' AS component_type,

        memory_type AS component_name,
        memory_size_gb AS spec_1,
        frequency_mhz AS spec_2,
        NULL AS spec_3,

        -- FIXED SCORING (adapted to your data)
        CASE 
            WHEN memory_size_gb >= 8 THEN 3
            WHEN memory_size_gb >= 4 THEN 2
            WHEN memory_size_gb >= 2 THEN 1
            ELSE 0
        END AS performance_score,

        CASE 
            WHEN memory_size_gb >= 8 THEN 'high'
            WHEN memory_size_gb >= 4 THEN 'medium'
            ELSE 'low'
        END AS performance_tier,

        source_year

    FROM {{ ref('stg_glpi_devicememories') }}

),

gpu AS (

    SELECT
        gpu_pk AS component_id,
        'gpu' AS component_type,

        gpu_brand AS component_name,
        vram_gb AS spec_1,
        NULL AS spec_2,
        gpu_type AS spec_3,

        -- FIXED GPU LOGIC (important)
        CASE 
            WHEN gpu_type = 'integrated' AND vram_gb >= 1.5 THEN 2
            WHEN gpu_type = 'integrated' THEN 1

            WHEN vram_gb >= 2 THEN 3
            WHEN vram_gb >= 1 THEN 2
            WHEN vram_gb IS NULL AND gpu_type = 'dedicated' THEN 'medium'
            ELSE 1
        END AS performance_score,

        CASE 
            WHEN gpu_type = 'integrated' AND vram_gb >= 1.5 THEN 'medium'
            WHEN gpu_type = 'integrated' THEN 'low'

            WHEN vram_gb >= 2 THEN 'high'
            WHEN vram_gb >= 1 THEN 'medium'
            ELSE 'low'
        END AS performance_tier,

        source_year

    FROM {{ ref('stg_glpi_devicegraphiccards') }}

),

final AS (

    SELECT * FROM cpu
    UNION ALL
    SELECT * FROM memory
    UNION ALL
    SELECT * FROM gpu

)

SELECT * FROM final