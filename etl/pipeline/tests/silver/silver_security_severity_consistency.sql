-- severity_score must be consistent with severity_level
SELECT security_event_pk, severity_level, severity_score
FROM {{ ref('silver_security_events') }}
WHERE
    (severity_level = 'critical' AND severity_score != 5)
    OR (severity_level = 'high'     AND severity_score != 4)
    OR (severity_level = 'medium'   AND severity_score != 3)
    OR (severity_level = 'low'      AND severity_score != 2)
    OR (
        (severity_level NOT IN ('critical', 'high', 'medium', 'low')
        OR severity_level IS NULL)          -- ✅ catch NULLs explicitly
        AND severity_score != 1
    )