-- escalation_probability must be between 0 and 10
SELECT ticket_fk, escalation_probability
FROM {{ ref('silver_triage_features') }}
WHERE escalation_probability < 0 OR escalation_probability > 10
