-- =============================================================
-- 06_gold_layer.sql
-- Fabric Warehouse: RetailWarehouse
-- Scenario 02: Healthcare Patient Readmission Prediction

-- STEP A: Dimension tables
-- =============================================================

-- dim_patient: patient demographics
CREATE TABLE dim_patient AS
SELECT DISTINCT
    patient_nbr,
    age,
    gender,
    race,
    CASE
        WHEN age IN ('[0-10)','[10-20)','[20-30)') THEN 'Under 30'
        WHEN age IN ('[30-40)','[40-50)','[50-60)') THEN '30-60'
        WHEN age IN ('[60-70)','[70-80)')            THEN '60-80'
        ELSE 'Over 80'
    END AS age_group
FROM [RetailLakehouse].[dbo].[silver_encounters_clean];
GO

-- dim_diagnosis_category: lookup for ICD-9 categories
CREATE TABLE dim_diagnosis_category AS
SELECT category_name, category_description FROM (
    VALUES
    ('circulatory',    'Heart disease, hypertension, arrhythmias'),
    ('diabetes',       'Diabetes mellitus — all types'),
    ('respiratory',    'Asthma, COPD, pneumonia'),
    ('digestive',      'GI disorders, liver disease'),
    ('neoplasm',       'Benign and malignant tumours'),
    ('musculoskeletal','Arthritis, fractures, spine'),
    ('genitourinary',  'Kidney, urinary tract, reproductive'),
    ('injury',         'Trauma, poisoning, burns'),
    ('unknown',        'Missing or unparseable ICD-9 code'),
    ('other',          'All other diagnosis categories')
) AS t(category_name, category_description);
GO

-- STEP B: Central fact table
-- =============================================================

CREATE TABLE fact_encounters AS
SELECT
    f.encounter_id,
    f.patient_nbr,
    -- Clinical features
    f.time_in_hospital,
    f.num_lab_procedures,
    f.num_procedures,
    f.num_medications,
    f.number_diagnoses,
    f.number_inpatient,
    f.number_emergency,
    f.number_outpatient,
    f.prior_visits_total,
    f.is_high_prior_use,
    f.is_long_stay,
    f.is_polypharmacy,
    f.is_complex_patient,
    -- Diagnosis
    f.diag1_cat,
    f.is_diabetes_primary,
    f.has_circulatory_dx,
    -- Medication
    f.total_med_changes,
    f.insulin_changed,
    -- Lab
    f.A1C_tested,
    f.A1C_high,
    -- ML output
    r.risk_score_pct,
    r.risk_tier,
    r.actual_readmit_30d
FROM [RetailLakehouse].[dbo].[silver_features]    f
JOIN [RetailLakehouse].[dbo].[silver_risk_scores]  r
    ON f.encounter_id = r.encounter_id;
GO

-- STEP C: Pre-aggregated tables for Power BI performance
-- =============================================================

-- Readmission rate by primary diagnosis category
CREATE TABLE agg_readmit_by_diag AS
SELECT
    diag1_cat,
    COUNT(*)                                            AS total_encounters,
    SUM(actual_readmit_30d)                             AS total_readmits,
    ROUND(
        AVG(CAST(actual_readmit_30d AS FLOAT)) * 100, 1
    )                                                   AS readmit_rate_pct,
    ROUND(AVG(risk_score_pct), 1)                       AS avg_risk_score,
    ROUND(AVG(CAST(is_high_prior_use AS FLOAT)) * 100, 1) AS pct_high_prior_use
FROM fact_encounters
GROUP BY diag1_cat;
GO

-- Readmission rate by age group and gender
CREATE TABLE agg_readmit_by_demographic AS
SELECT
    p.age_group,
    e.diag1_cat,
    COUNT(*)                                            AS total_encounters,
    SUM(e.actual_readmit_30d)                           AS total_readmits,
    ROUND(
        AVG(CAST(e.actual_readmit_30d AS FLOAT)) * 100, 1
    )                                                   AS readmit_rate_pct,
    ROUND(AVG(e.risk_score_pct), 1)                     AS avg_risk_score
FROM fact_encounters e
JOIN dim_patient     p ON e.patient_nbr = p.patient_nbr
GROUP BY p.age_group, e.diag1_cat;
GO

-- STEP D: Alert view — Data Activator monitors this
-- =============================================================

-- Returns all HIGH-risk patients currently flagged.
-- Data Activator checks this view every 30 minutes.
-- When a new row appears (new HIGH patient), alert fires.
CREATE VIEW vw_high_risk_discharge AS
SELECT
    e.encounter_id,
    e.patient_nbr,
    p.age,
    p.gender,
    p.age_group,
    e.diag1_cat,
    e.risk_score_pct,
    e.risk_tier,
    e.time_in_hospital,
    e.num_medications,
    e.number_inpatient     AS prior_inpatient_visits,
    e.A1C_tested,
    e.insulin_changed,
    GETDATE()              AS alert_generated_at
FROM fact_encounters   e
JOIN dim_patient       p ON e.patient_nbr = p.patient_nbr
WHERE e.risk_tier = 'HIGH';
GO

-- STEP E: Validation
-- =============================================================

SELECT 'dim_patient'               AS obj, COUNT(*) AS rows FROM dim_patient
UNION ALL SELECT 'dim_diagnosis_category',  COUNT(*) FROM dim_diagnosis_category
UNION ALL SELECT 'fact_encounters',          COUNT(*) FROM fact_encounters
UNION ALL SELECT 'agg_readmit_by_diag',      COUNT(*) FROM agg_readmit_by_diag
UNION ALL SELECT 'agg_readmit_by_demographic',COUNT(*) FROM agg_readmit_by_demographic
UNION ALL SELECT 'vw_high_risk_discharge',    COUNT(*) FROM vw_high_risk_discharge;
