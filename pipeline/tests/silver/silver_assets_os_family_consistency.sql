-- Os family should align with os_name patterns
SELECT asset_pk, os_name, os_family
FROM {{ ref('silver_assets') }}
WHERE
    (LOWER(os_name) LIKE '%windows%' AND os_family != 'Windows')
    OR (LOWER(os_name) LIKE '%linux%' AND os_family != 'Linux')
    OR (LOWER(os_name) LIKE '%ubuntu%' AND os_family != 'Linux')
    OR (LOWER(os_name) LIKE '%debian%' AND os_family != 'Linux')
    OR (LOWER(os_name) LIKE '%mac%' AND os_family != 'MacOS')
