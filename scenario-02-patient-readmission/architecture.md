# Architecture: Microsoft Fabric Implementation

## High‑Level Design

The solution is implemented entirely within a Microsoft Fabric workspace named `PatientReadmissionPrediction`, using a Lakehouse‑centric medallion architecture (bronze → silver → feature → ML).

Core components:

- **Workspace:** `PatientReadmissionPrediction` – logical container for Lakehouse, notebooks, and ML artifacts.  
- **Lakehouse:** `lh_healthcare_readmission` – central storage with Files (raw) and Tables (Delta).  
- **Notebooks:** Four PySpark notebooks implement the data and ML pipeline.
- **ML Tracking:** MLflow experiment `HospitalReadmission30Day` and registered model `HospitalReadmission30d`.

## Data Layers

### Bronze Layer

- **Raw file:** `Files/bronze/diabetic_data.csv` – Kaggle dataset uploaded to the Lakehouse Files area. 
- **Notebook:** `01-Load_Bronze_Table.ipynb`.
- **Operations:**
  - Read CSV with header using Spark. 
  - Normalize column names by replacing spaces and special characters with underscores to satisfy Delta constraints.
  - Persist as Delta table **`bronze_encounters`** within the Lakehouse, with 101,766 rows and 50 columns.

### Silver Layer

- **Notebook:** `02_silver_cleaning.py.ipynb`.
- **Input:** `bronze_encounters`.
- **Key steps:**
  - Replace `'?'` with nulls for selected columns (`race`, `diag1`, `diag2`, `diag3`, `payer_code`, `medical_specialty`, `weight`). 
  - Drop `weight` due to ~97 % missingness; keep `payer_code` and `medical_specialty` despite high nulls for potential analysis and filtering.
  - Cast numeric columns (e.g., `time_in_hospital`, `num_lab_procedures`, `num_procedures`, `num_medications`, `number_diagnoses`, utilization counts, IDs) to integer.
  - Deduplicate to one encounter per patient using a window over `patient_nbr` ordered by descending `encounter_id`, keeping the most recent encounter (reducing from 101,766 to 71,518 records). [file:4]  
  - Encode age bands into an ordinal feature `age_ord` from 0 to 9, preserving order across brackets such as `[0-10)`, `[10-20)`, …, `[90-100)`.
  - Derive binary label `readmitted30d` from `readmitted` ("<30" → 1, others → 0), yielding a 4.5 % positive rate and an approximate negative:positive ratio of 22:1.
  - Null audit to document missingness (e.g., ~48 % for `medical_specialty`, ~42 % for `payer_code`).
  - Persist as Delta table **`silver_encounters_clean`** with 71,518 rows and 51 columns.

### Feature Layer

- **Notebook:** `03_feature_engineering.py.ipynb`.
- **Input:** `silver_encounters_clean`.  
- **Key feature blocks:**
  - Diagnosis grouping into ~9 clinical categories (`circulatory`, `diabetes`, `respiratory`, `digestive`, `neoplasm`, `musculoskeletal`, `genitourinary`, `injury`, `other/unknown`) using ICD‑9 code ranges to create `diag1cat`, `diag2cat`, `diag3cat`.
  - Flags `is_diabetes_primary` and `has_circulatory_dx` to capture whether diabetes is the primary diagnosis and whether any diagnosis involves circulatory disease.
  - Diabetes medication change features: `total_med_changes`, `total_meds_taken`, `insulin_changed`, `insulin_increased`, based on patterns like `Up`, `Down`, `Steady`, `No` in the medication columns. 
  - Lab features: `A1C_tested`, `A1C_high`, `A1C_normal`, and `glucose_tested` from HbA1c and serum glucose fields. 
  - Prior healthcare utilization features: `prior_visits_total`, `is_high_prior_use` (≥ 3 visits in past year), `has_prior_inpatient`, `has_prior_emergency`, `is_long_stay` (length of stay ≥ 7 days), `is_polypharmacy` (≥ 15 medications), `is_complex_patient` (number of diagnoses > 7).
  - Categorical encoding via `StringIndexer` for `diag1cat`, `diag2cat`, `diag3cat`, `gender`, `race`, `change`, and `diabetesMed`, generating `*_idx` columns with `handleInvalid="keep"`.

A curated list of 31 model features is assembled (e.g., utilization metrics, lab flags, medication change indicators, diagnosis and demographic encodings) and stored in **`silver_features`** with 71,518 rows and 78 total columns.

### ML & Experimentation Layer

- **Notebook:** `04_ml_experiment.py.ipynb`. [file:1]  
- **Input:** `silver_features`.
- **Features/target:**
  - `X` = selected feature columns (31 engineered features). 
  - `y` = `readmitted30d`.

MLflow is configured with experiment name **`HospitalReadmission30Day`**, and all model parameters and metrics are logged under this experiment. 
A trained XGBoost model is registered as **`HospitalReadmission30d`** via `mlflow.sklearn.log_model`.

## Logical Flow

1. **Ingest** raw CSV into bronze Delta table.
2. **Transform & cleanse** into silver table with one record per patient and a clean binary target.
3. **Engineer features** into a dedicated features table optimized for ML.
4. **Train & track model** with MLflow, ready to be used by downstream scoring notebooks or Fabric Data Pipelines.

This architecture is fully compatible with future extensions such as real‑time scoring endpoints, Power BI readmission‑risk dashboards, or scheduled batch scoring pipelines in Fabric.