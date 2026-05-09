SELECT *
FROM {{ ref('dim_users') }}
WHERE last_activity_at < first_activity_at