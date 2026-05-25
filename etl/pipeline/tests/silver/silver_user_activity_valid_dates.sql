-- activity date should not be in the future
SELECT activity_pk, activity_date
FROM {{ ref('silver_user_activity') }}
WHERE activity_date > CURRENT_TIMESTAMP
