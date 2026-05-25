SELECT *

FROM {{ ref('stg_cve_kaggle') }}

WHERE cve_pk IS NULL

   OR (
        cvss_score IS NOT NULL
        AND (
            cvss_score < 0
            OR cvss_score > 10
        )
   )

   OR severity_level NOT IN (
        'critical',
        'high',
        'medium',
        'low',
        'unknown'
   )

   OR is_remote_exploitable IS NULL

   OR is_critical IS NULL

   OR easy_to_exploit IS NULL