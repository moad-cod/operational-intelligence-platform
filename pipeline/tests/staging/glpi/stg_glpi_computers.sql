SELECT *

FROM {{ ref('stg_glpi_computers') }}

WHERE unique_id IS NULL

   OR computer_id IS NULL

   OR computer_name IS NULL