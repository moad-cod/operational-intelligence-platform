SELECT *
FROM {{ ref('stg_ocs_bios') }}
WHERE serial_number IN ('12345678', 'oem_serial', 'system serial number')