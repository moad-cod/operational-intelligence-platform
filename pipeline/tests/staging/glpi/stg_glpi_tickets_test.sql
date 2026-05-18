SELECT *

FROM {{ ref('stg_glpi_tickets') }}

WHERE ticket_pk IS NULL

   OR ticket_id IS NULL

   OR priority_tier NOT IN (
        'critical',
        'high',
        'medium',
        'low',
        'unknown'
   )

   OR urgency_tier NOT IN (
        'critical',
        'high',
        'medium',
        'low',
        'unknown'
   )

   OR impact_tier NOT IN (
        'critical',
        'high',
        'medium',
        'low',
        'unknown'
   )

   OR source_year NOT IN (
        2013,
        2014,
        2015
   )

   OR source_system != 'GLPI'