-- sla_risk_score must be between 0 and 10
SELECT ticket_fk, sla_risk_score
FROM {{ ref('silver_triage_features') }}
WHERE sla_risk_score < 0 OR sla_risk_score > 10
