WITH cve_events AS (

    SELECT
        MD5(CONCAT('CVE_', cve_pk)) AS security_event_pk,
        'CVE' AS event_type,
        cve_pk AS source_key,
        cwe_code,
        cwe_name,
        cve_summary AS event_description,
        published_at AS event_date,
        modified_at AS updated_at,
        cvss_score,
        severity_level,
        access_authentication,
        access_complexity,
        access_vector,
        impact_availability,
        impact_confidentiality,
        impact_integrity,
        is_remote_exploitable,
        is_critical,
        easy_to_exploit,
        NULL AS machine_name,
        NULL AS event_source,
        NULL AS country
    FROM {{ ref('stg_cve_kaggle') }}

),

windows_events AS (

    SELECT
        MD5(CONCAT('WINLOG_', eventlog_pk)) AS security_event_pk,
        'WINDOWS_EVENT' AS event_type,
        eventlog_pk AS source_key,
        NULL AS cwe_code,
        NULL AS cwe_name,
        COALESCE(event_message, CONCAT(event_source, ': ', event_category)) AS event_description,
        generated_at AS event_date,
        NULL AS updated_at,
        NULL AS cvss_score,
        severity_level,
        NULL AS access_authentication,
        NULL AS access_complexity,
        NULL AS access_vector,
        NULL AS impact_availability,
        NULL AS impact_confidentiality,
        NULL AS impact_integrity,
        FALSE AS is_remote_exploitable,
        CASE WHEN severity_level IN ('critical', 'high') THEN TRUE ELSE FALSE END AS is_critical,
        FALSE AS easy_to_exploit,
        machine_name,
        event_source,
        country
    FROM {{ ref('stg_windows_eventlog_kaggle') }}

),

security_tickets AS (

    SELECT
        MD5(CONCAT('TICKET_SEC_', t.ticket_pk)) AS security_event_pk,
        'TICKET' AS event_type,
        t.ticket_pk AS source_key,
        NULL AS cwe_code,
        NULL AS cwe_name,
        NULL AS event_description,
        t.created_at AS event_date,
        t.closed_at AS updated_at,
        NULL AS cvss_score,
        CASE
            WHEN t.priority_tier IN ('critical', 'high') THEN t.priority_tier
            ELSE 'informational'
        END AS severity_level,
        NULL AS access_authentication,
        NULL AS access_complexity,
        NULL AS access_vector,
        NULL AS impact_availability,
        NULL AS impact_confidentiality,
        NULL AS impact_integrity,
        FALSE AS is_remote_exploitable,
        CASE WHEN t.priority_tier IN ('critical', 'high') THEN TRUE ELSE FALSE END AS is_critical,
        FALSE AS easy_to_exploit,
        NULL AS machine_name,
        'GLPI' AS event_source,
        NULL AS country
    FROM {{ ref('stg_glpi_tickets') }} t
    -- ✅ filter only critical/high tickets as proxy for security relevance
    -- since there is no category FK in stg_glpi_tickets
    WHERE t.priority_tier IN ('critical', 'high')

)

-- ✅ no deduped CTE — MD5 keys never collide across sources
SELECT
    security_event_pk,
    event_type,
    event_date,
    COALESCE(updated_at, event_date) AS last_updated,
    severity_level,
    CASE
        WHEN severity_level = 'critical' THEN 5
        WHEN severity_level = 'high'     THEN 4
        WHEN severity_level = 'medium'   THEN 3
        WHEN severity_level = 'low'      THEN 2
        ELSE 1
    END AS severity_score,
    event_description,
    cwe_code,
    cwe_name,
    cvss_score,
    is_remote_exploitable,
    is_critical,
    easy_to_exploit,
    access_vector,
    access_complexity,
    access_authentication,
    impact_confidentiality,
    impact_integrity,
    impact_availability,
    machine_name,
    event_source,
    country
FROM (
    SELECT * FROM cve_events
    UNION ALL
    SELECT * FROM windows_events
    UNION ALL
    SELECT * FROM security_tickets
) AS unified