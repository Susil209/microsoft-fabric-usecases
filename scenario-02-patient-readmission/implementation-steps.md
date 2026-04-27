# Implementation Steps in Microsoft Fabric

This document describes how to reproduce the end‑to‑end pipeline in Microsoft Fabric, from raw ingestion to a registered model.

## 1. Environment Setup

1. Create a Fabric **workspace** named `PatientReadmissionPrediction`.  
2. Inside the workspace, create a **Lakehouse** named `lh_healthcare_readmission`.  
3. In the Lakehouse Files area, create a folder `bronze` and upload `diabetic_data.csv` from the Kaggle dataset.

## 2. Bronze Ingestion (01-Load_Bronze_Table)

**Notebook:** `01-Load_Bronze_Table.ipynb`.

Steps:

1. Use PySpark (`spark.read.format("csv").option("header", "true")`) to read `Files/bronze/diabetic_data.csv`.
2. Normalize column names by replacing spaces and invalid characters (e.g., commas, brackets, periods) with underscores to make them Delta‑compatible.
3. Write the resulting DataFrame as a Delta table `bronze_encounters` using `df.write.format("delta").mode("overwrite").saveAsTable("bronze_encounters")`.
4. Optionally, reload the table via `spark.read.table("bronze_encounters")` and print row and column counts to verify (101,766 rows, 50 columns). 

## 3. Silver Cleaning (02_silver_cleaning.py)

**Notebook:** `02_silver_cleaning.py.ipynb`. [file:4]

Steps:

1. Read the bronze table: `df = spark.read.format("delta").table("bronze_encounters")`. 
2. Replace `'?'` with null for selected columns: `race`, `diag1`, `diag2`, `diag3`, `payer_code`, `medical_specialty`, `weight`. 
3. Drop **`weight`** due to ~97 % missingness; retain `payer_code` and `medical_specialty` for potential downstream filtering and analysis despite high missingness. 
4. Cast numeric fields such as `time_in_hospital`, `num_lab_procedures`, `num_procedures`, `num_medications`, `number_diagnoses`, `number_inpatient`, `number_emergency`, `number_outpatient`, `encounter_id`, and `patient_nbr` to `IntegerType`. 
5. Deduplicate to one encounter per patient using a window partitioned by `patient_nbr` ordered by `encounter_id` descending, keeping only rank 1; this reduces from 101,766 to 71,518 rows. 
6. Encode age bands into an ordinal integer feature `age_ord` (0–9) corresponding to brackets like `[0-10)`, `[10-20)`, …, `[90-100)`. 
7. Derive the **binary target** `readmitted30d` from the original `readmitted` column, mapping `<30` to 1 and other values to 0, resulting in a 4.5 % positive rate and imbalance ratio about 22:1. 
8. Run a small null audit to understand missingness across columns, flagging `medical_specialty` and `payer_code` as high‑null but retained. 
9. Write the cleaned DataFrame as `silver_encounters_clean` with `mode("overwrite").option("overwriteSchema", "true")`. [file:4]

## 4. Feature Engineering (03_feature_engineering.py)

**Notebook:** `03_feature_engineering.py.ipynb`.

Steps:

1. Load `silver_encounters_clean`: `df = spark.read.format("delta").table("silver_encounters_clean")` (71,518 input rows). 
2. Map ICD‑9 diagnosis codes (`diag1`, `diag2`, `diag3`) into clinical categories (`diag1cat`, `diag2cat`, `diag3cat`) using regex‑based ranges for circulatory, diabetes, respiratory, digestive, neoplasms, musculoskeletal, genitourinary, injury, and other/unknown groups. 
3. Create flags:
   - `is_diabetes_primary` – 1 if the primary diagnosis (`diag1`) is diabetes; 0 otherwise.  
   - `has_circulatory_dx` – 1 if any of `diag1cat`, `diag2cat`, or `diag3cat` is circulatory.  
4. From the diabetes medication columns, compute:
   - `total_med_changes` – count of drugs with `Up` or `Down` dosage changes.  
   - `total_meds_taken` – count of diabetes drugs prescribed (`Steady`, `Up`, or `Down`).  
   - `insulin_changed` – 1 if insulin column is `Up` or `Down`.  
   - `insulin_increased` – 1 if insulin column is `Up`.  
5. Build lab‑derived features:
   - `A1C_tested`, `A1C_high`, `A1C_normal` from `A1Cresult`.  
   - `glucose_tested` from `max_glu_serum` when present. 
6. Build prior utilization and complexity features:
   - `prior_visits_total` = `number_inpatient + number_emergency + number_outpatient`.  
   - `is_high_prior_use` – 1 if `prior_visits_total ≥ 3`.  
   - `has_prior_inpatient`, `has_prior_emergency` – flags for any prior admissions/ED visits.  
   - `is_long_stay` – 1 if `time_in_hospital ≥ 7`.  
   - `is_polypharmacy` – 1 if `num_medications ≥ 15`.   
   - `is_complex_patient` – 1 if `number_diagnoses > 7`. 
7. Encode categorical variables (`diag1cat`, `diag2cat`, `diag3cat`, `gender`, `race`, `change`, `diabetesMed`) with `StringIndexer` to produce `diag1cat_idx`, `diag2cat_idx`, `diag3cat_idx`, `gender_idx`, `race_idx`, `change_idx`, and `diabetesMed_idx` using `handleInvalid="keep"`.
8. Select a curated list of 31 feature columns (`FEATURE_COLS`) covering utilization, labs, medications, diagnoses, and demographics, and persist the result as `silver_features`.

The final `silver_features` table has 71,518 rows and 78 total columns, including the original fields, engineered features, encodings, and the target.

## 5. Model Training & Experiment Tracking (04_ml_experiment.py)

**Notebook:** `04_ml_experiment.py.ipynb`.

Steps:

1. Configure MLflow:
   - Set experiment name to `HospitalReadmission30Day`. 
2. Load features:
   - Read `silver_features` as a Spark DataFrame and convert to Pandas for modeling.
   - Select the 31 feature columns and the `readmitted30d` target. 
   - Confirm ~71,518 records with a 4.5 % positive rate. 
3. Analyze class imbalance:
   - Compute positive and negative counts, positive rate, and `scale_pos_weight = (negatives / positives)` (~21.2). 
4. Define XGBoost classifier with parameters:
   - `n_estimators=500`, `learning_rate=0.05`, `max_depth=6`, `subsample=0.8`, `colsample_bytree=0.8`, `min_child_weight=5`, `gamma=0.1`, `reg_alpha=0.1`, `reg_lambda=1.0`. 
   - `scale_pos_weight ≈ 21.18`, `eval_metric="auc"`, `use_label_encoder=False`, `random_state=42`, `n_jobs=-1`, `verbosity=0`. 
5. Perform 5‑fold stratified cross‑validation:
   - Use `StratifiedKFold(n_splits=5, shuffle=True, random_state=42)` and `cross_val_score` with `scoring="roc_auc"`. 
   - Achieve mean AUC‑ROC 0.6433 with standard deviation 0.0074. 
6. Train final model with train/test split:
   - Split into train (80 %) and test (20 %) with stratification on `y`.
   - Train XGBoost with early stopping (`early_stopping_rounds=50`) on a validation set, tracking `best_iteration=32`.
   - Evaluate on the test set, using probability threshold 0.35 for positive predictions.
7. Compute metrics:
   - Test AUC‑ROC: 0.6647.
   - Average precision (PR‑AUC): 0.0942.  
8. Explainability:
   - Fit a SHAP `TreeExplainer` and compute mean absolute SHAP values on a sample of test rows to produce feature importance.
   - Top features include `number_inpatient`, `age_ord`, `num_lab_procedures`, `prior_visits_total`, `number_diagnoses`, `time_in_hospital`, `num_medications`, `has_prior_inpatient`, `race_idx`, and `diag1cat_idx`. 
9. MLflow logging and model registration:
   - Log feature counts, train/test sizes, positive rate, and `scale_pos_weight`.
   - Log all XGBoost hyperparameters and metrics (`AUCROC`, `AvgPrecision`, `CVAUCmean`, `CVAUCstd`, `best_iteration`). 
   - Save SHAP feature importance as a CSV artifact and log via MLflow. 
   - Register the model as `HospitalReadmission30d` through `mlflow.sklearn.log_model`.

## 6. Next Steps (Optional)

- Add a scoring notebook (e.g., `05_risk_scoring.py`) that:
  - Reads new encounter data from `silver_encounters_clean` or a streaming source.  
  - Applies the same feature logic or reads `silver_features`.  
  - Loads the registered model `HospitalReadmission30d` from MLflow and returns risk scores per patient.
- Connect a Power BI report to the Lakehouse tables to visualize readmission risk distributions and top risk drivers.