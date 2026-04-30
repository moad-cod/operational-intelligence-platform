{% test change_type_consistency(model) %}

SELECT *
FROM {{ model }}
WHERE

    (
        change_type = 'created'
        AND NOT (
            (old_value IS NULL OR old_value = '')
            AND (new_value IS NOT NULL AND new_value != '')
        )
    )

    OR

    (
        change_type = 'deleted'
        AND NOT (
            (old_value IS NOT NULL AND old_value != '')
            AND (new_value IS NULL OR new_value = '')
        )
    )

    OR

    (
        change_type = 'updated'
        AND (old_value = new_value)
    )

    OR

    (
        change_type = 'no_change'
        AND old_value != new_value
    )

{% endtest %}