-- Validate the MIMIC-IV tables built correctly by checking against known row counts
-- of MIMIC-IV v3.1
SELECT
    CASE
        WHEN exp.row_count = obs.row_count
        THEN 'PASSED'
        ELSE 'FAILED'
    END AS chk
    , exp.row_count AS exp
    , obs.row_count AS obs
    , exp.tbl
-- expected row count - hard-coded based off known values
FROM (
    SELECT 'admissions' AS tbl,         546028 AS row_count UNION ALL
    SELECT 'd_hcpcs' AS tbl,            89208 AS row_count UNION ALL
    SELECT 'd_icd_diagnoses' AS tbl,    112107 AS row_count UNION ALL
    SELECT 'd_icd_procedures' AS tbl,   86423 AS row_count UNION ALL
    SELECT 'd_labitems' AS tbl,         1650 AS row_count UNION ALL
    SELECT 'diagnoses_icd' AS tbl,      6364488 AS row_count UNION ALL
    SELECT 'drgcodes' AS tbl,           761856 AS row_count UNION ALL
    SELECT 'emar' AS tbl,               42808593 AS row_count UNION ALL
    SELECT 'emar_detail' AS tbl,        87371064 AS row_count UNION ALL
    SELECT 'hcpcsevents' AS tbl,        186074 AS row_count UNION ALL
    SELECT 'labevents' AS tbl,          158374764 AS row_count UNION ALL
    SELECT 'microbiologyevents' AS tbl, 3988224 AS row_count UNION ALL
    SELECT 'omr' AS tbl,                7753027 AS row_count UNION ALL
    SELECT 'patients' AS tbl,           364627 AS row_count UNION ALL
    SELECT 'pharmacy' AS tbl,           17847567 AS row_count UNION ALL
    SELECT 'poe' AS tbl,                52212109 AS row_count UNION ALL
    SELECT 'poe_detail' AS tbl,         8504982 AS row_count UNION ALL
    SELECT 'prescriptions' AS tbl,      20292611 AS row_count UNION ALL
    SELECT 'procedures_icd' AS tbl,     859655 AS row_count UNION ALL
    SELECT 'services' AS tbl,           593071 AS row_count UNION ALL
    SELECT 'transfers' AS tbl,          2413581 AS row_count UNION ALL
    -- icu data
    SELECT 'icustays' AS tbl,           94458 AS row_count UNION ALL
    SELECT 'd_items' AS tbl,            4095 AS row_count UNION ALL
    SELECT 'chartevents' AS tbl,        432997491 AS row_count UNION ALL
    SELECT 'datetimeevents' AS tbl,     9979761 AS row_count UNION ALL
    SELECT 'inputevents' AS tbl,        10953713 AS row_count UNION ALL
    SELECT 'outputevents' AS tbl,       5359395 AS row_count UNION ALL
    SELECT 'procedureevents' AS tbl,    808706 AS row_count
) exp
-- observed row count
INNER JOIN
(
    SELECT 'admissions' AS tbl, count(*) AS row_count FROM admissions UNION ALL
    SELECT 'd_hcpcs' AS tbl, count(*) AS row_count FROM d_hcpcs UNION ALL
    SELECT 'd_icd_diagnoses' AS tbl, count(*) AS row_count FROM d_icd_diagnoses UNION ALL
    SELECT 'd_icd_procedures' AS tbl, count(*) AS row_count FROM d_icd_procedures UNION ALL
    SELECT 'd_labitems' AS tbl, count(*) AS row_count FROM d_labitems UNION ALL
    SELECT 'diagnoses_icd' AS tbl, count(*) AS row_count FROM diagnoses_icd UNION ALL
    SELECT 'drgcodes' AS tbl, count(*) AS row_count FROM drgcodes UNION ALL
    SELECT 'emar' AS tbl, count(*) AS row_count FROM emar UNION ALL
    SELECT 'emar_detail' AS tbl, count(*) AS row_count FROM emar_detail UNION ALL
    SELECT 'hcpcsevents' AS tbl, count(*) AS row_count FROM hcpcsevents UNION ALL
    SELECT 'labevents' AS tbl, count(*) AS row_count FROM labevents UNION ALL
    SELECT 'microbiologyevents' AS tbl, count(*) AS row_count FROM microbiologyevents UNION ALL
    SELECT 'omr' AS tbl, count(*) AS row_count FROM omr UNION ALL
    SELECT 'patients' AS tbl, count(*) AS row_count FROM patients UNION ALL
    SELECT 'pharmacy' AS tbl, count(*) AS row_count FROM pharmacy UNION ALL
    SELECT 'poe' AS tbl, count(*) AS row_count FROM poe UNION ALL
    SELECT 'poe_detail' AS tbl, count(*) AS row_count FROM poe_detail UNION ALL
    SELECT 'prescriptions' AS tbl, count(*) AS row_count FROM prescriptions UNION ALL
    SELECT 'procedures_icd' AS tbl, count(*) AS row_count FROM procedures_icd UNION ALL
    SELECT 'services' AS tbl, count(*) AS row_count FROM services UNION ALL
    SELECT 'transfers' AS tbl, count(*) AS row_count FROM transfers UNION ALL
    -- icu data
    SELECT 'icustays' AS tbl, count(*) AS row_count FROM icustays UNION ALL
    SELECT 'chartevents' AS tbl, count(*) AS row_count FROM chartevents UNION ALL
    SELECT 'd_items' AS tbl, count(*) AS row_count FROM d_items UNION ALL
    SELECT 'datetimeevents' AS tbl, count(*) AS row_count FROM datetimeevents UNION ALL
    SELECT 'inputevents' AS tbl, count(*) AS row_count FROM inputevents UNION ALL
    SELECT 'outputevents' AS tbl, count(*) AS row_count FROM outputevents UNION ALL
    SELECT 'procedureevents' AS tbl, count(*) AS row_count FROM procedureevents
) obs
  ON exp.tbl = obs.tbl
ORDER BY exp.tbl
;
