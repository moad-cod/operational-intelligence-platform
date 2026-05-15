WITH source AS (

    SELECT *

    FROM {{ source('bronze', 'bronze_glpi_devicegraphiccards') }}

),

base AS (

    SELECT

        -- =====================================
        -- PRIMARY KEY
        -- =====================================

        CONCAT(source_year, '_', id) AS gpu_pk,

        id AS gpu_id,

        -- =====================================
        -- GPU CLEANING
        -- =====================================

        CASE

            WHEN designation IS NULL THEN NULL

            WHEN TRIM(designation) IN ('', '4', '5') THEN NULL

            WHEN LOWER(designation) LIKE '%contrôleur%' THEN NULL

            WHEN LOWER(designation) LIKE '%basic render%' THEN NULL

            WHEN LOWER(designation) LIKE '%carte graphique vga standard%' THEN NULL

            WHEN LOWER(designation) LIKE '%microsoft basic render%' THEN NULL

            ELSE TRIM(designation)

        END AS gpu_name,

        designation,

        -- =====================================
        -- VRAM NORMALIZATION
        -- =====================================

        ROUND(

            CASE

                WHEN specif_default IS NULL THEN NULL

                WHEN specif_default = 0 THEN NULL

                ELSE specif_default / 1024

            END,

            2

        ) AS vram_gb,

        -- =====================================
        -- METADATA
        -- =====================================

        source_year,

        source_system

    FROM source

),

cleaned AS (

    SELECT

        gpu_pk,

        gpu_id,

        gpu_name,

        -- =====================================
        -- GPU BRAND
        -- =====================================

        CASE

            WHEN gpu_name LIKE '%NVIDIA%' THEN 'NVIDIA'

            WHEN gpu_name LIKE '%GeForce%' THEN 'NVIDIA'

            WHEN gpu_name LIKE '%Quadro%' THEN 'NVIDIA'

            WHEN gpu_name LIKE '%Intel%' THEN 'Intel'

            WHEN gpu_name LIKE '%AMD%' THEN 'AMD'

            WHEN gpu_name LIKE '%Radeon%' THEN 'AMD'

            WHEN gpu_name LIKE '%ATI%' THEN 'AMD'

            WHEN gpu_name LIKE '%Matrox%' THEN 'Matrox'

            ELSE 'Other'

        END AS gpu_brand,

        -- =====================================
        -- GPU TYPE
        -- =====================================

        CASE

            WHEN gpu_name LIKE '%Intel%' THEN 'integrated'

            WHEN gpu_name LIKE '%Express Chipset%' THEN 'integrated'

            WHEN gpu_name LIKE '%XPRESS%' THEN 'integrated'

            WHEN gpu_name LIKE '%Microsoft%' THEN 'virtual'

            WHEN gpu_name LIKE '%Basic Render%' THEN 'virtual'

            ELSE 'dedicated'

        END AS gpu_type,

        vram_gb,

        source_year,

        source_system

    FROM base

    WHERE gpu_name IS NOT NULL

),

final AS (

    SELECT

        *,

        -- =====================================
        -- PERFORMANCE TIER
        -- =====================================

        CASE

            WHEN gpu_type = 'virtual' THEN 'virtual'

            WHEN gpu_type = 'integrated' AND vram_gb >= 2 THEN 'medium'

            WHEN gpu_type = 'integrated' AND vram_gb >= 1 THEN 'medium'

            WHEN gpu_type = 'integrated' THEN 'low'

            WHEN vram_gb >= 4 THEN 'high'

            WHEN vram_gb >= 2 THEN 'medium'

            WHEN vram_gb >= 1 THEN 'medium'

            WHEN vram_gb IS NULL THEN 'unknown'

            ELSE 'low'

        END AS performance_tier

    FROM cleaned

)

SELECT *

FROM final