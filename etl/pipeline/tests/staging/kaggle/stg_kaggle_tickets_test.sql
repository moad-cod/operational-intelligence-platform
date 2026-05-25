SELECT *

FROM {{ ref('stg_kaggle_tickets') }}

WHERE unified_ticket_pk IS NULL

   OR source_dataset NOT IN (
        'customer_support_tickets_200k',
        'dataset_tickets_multi_lang'
   )

   OR (
        priority IS NOT NULL
        AND priority NOT IN (
            'low',
            'medium',
            'high',
            'critical',
            'urgent'
        )
   )

   OR is_escalated IS NULL

   OR is_sla_breached IS NULL