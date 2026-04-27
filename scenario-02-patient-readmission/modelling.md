# Modeling: 30‑Day Readmission Classifier

## Target Definition

The label `readmitted30d` is created from the original `readmitted` column with three categories: `<30`, `>30`, and `NO`.   
We define `readmitted30d = 1` if `readmitted == "<30"` and 0 otherwise, aligning with the 30‑day early readmission focus in the original clinical study. 

In the cleaned, deduplicated dataset (`silver_encounters_clean`), the positive rate is around 4.5 %, resulting in a highly imbalanced binary classification problem with an approximate 22:1 ratio of negatives to positives. 

## Feature Set

The model uses 31 engineered features from the `silver_features` table, grouped into several conceptual blocks. 

### Utilization & Severity Features

- `time_in_hospital` – length of stay in days.   
- `num_lab_procedures` – number of lab tests during the encounter.   
- `num_procedures` – non‑lab procedures performed.   
- `num_medications` – number of distinct medications administered.   
- `number_diagnoses` – count of diagnoses coded during the encounter.   
- `prior_visits_total` – sum of prior inpatient, emergency, and outpatient visits in the previous year.   
- `is_high_prior_use`, `has_prior_inpatient`, `has_prior_emergency`, `is_long_stay`, `is_polypharmacy`, `is_complex_patient`. 

These features capture both acute severity (length of stay, number of procedures) and chronic complexity or healthcare utilization patterns, which are known drivers of readmission risk. 

### Demographics & Age

- `age_ord` – ordinal encoding of age band (0–9).   
- `gender_idx` and `race_idx` – indexed categorical encodings of gender and race. 

The original study controlled for age, sex, and race to adjust for demographic risk profiles; the project mirrors this through numeric encodings. 

### Diagnosis & Comorbidity

- `diag1cat_idx`, `diag2cat_idx`, `diag3cat_idx` – indexed versions of diagnosis category groupings (circulatory, diabetes, respiratory, etc.).   
- `is_diabetes_primary` – indicates if diabetes is the primary admission diagnosis.   
- `has_circulatory_dx` – indicates if any recorded diagnosis is circulatory. 

These capture the clinically important distinction between patients admitted primarily for diabetes versus patients with diabetes as a comorbidity, as highlighted in the original analysis. 

### Medication & Lab Features

- Medication changes: `total_med_changes`, `total_meds_taken`, `insulin_changed`, `insulin_increased`.   
- Lab features: `A1C_tested`, `A1C_high`, `A1C_normal`, `glucose_tested`. 

The original paper emphasizes HbA1c testing frequency and response (medication changes) as key markers of attention to diabetes care and potential predictors of readmission. 
Our features approximate these concepts in a machine‑learning‑friendly form by consolidating medication changes and lab result categories. 

## Model Choice and Hyperparameters

The current baseline model is an **XGBoost** gradient tree boosting classifier (`XGBClassifier`) configured to handle severe class imbalance. 

Key hyperparameters:

- `n_estimators = 500`, `learning_rate = 0.05`, `max_depth = 6`.   
- `subsample = 0.8`, `colsample_bytree = 0.8`.   
- Regularization: `min_child_weight = 5`, `gamma = 0.1`, `reg_alpha = 0.1`, `reg_lambda = 1.0`.   
- `scale_pos_weight ≈ 21.18`, matching the negative:positive class ratio.   
- `eval_metric = "auc"`, `use_label_encoder = False`, `random_state = 42`, `n_jobs = -1`, `verbosity = 0`. 

These settings seek a balance between model complexity and generalization, while directly counteracting the imbalance through `scale_pos_weight`. 

## Training & Validation Strategy

1. **Train/test split** – 80/20 split with stratification on the target variable `readmitted30d`.   
2. **Cross‑validation** – 5‑fold stratified cross‑validation using `StratifiedKFold` with shuffling and `random_state=42`, scoring with ROC AUC.   
3. **Early stopping** – When training the final model, early stopping with 50 rounds is applied on a validation set, leading to `best_iteration = 32`. 

This combination provides:

- A robust estimate of generalization performance via CV.   
- Protection against overfitting the noisy clinical data through early stopping and regularization. 

## Performance Metrics

### Cross‑Validation

- **CV AUC‑ROC (5‑fold):** 0.6433 (mean) with standard deviation 0.0074.   

The narrow standard deviation suggests stable performance across folds, even under class imbalance. 

### Hold‑Out Test Set

- **AUC‑ROC:** 0.6647.   
- **Average Precision (PR‑AUC):** 0.0942, using a threshold of 0.35 for positive class predictions. 

Given the 4.5 % baseline positive rate, a PR‑AUC around 0.09 reflects a modest but meaningful improvement over random ranking in this challenging setting.   
The notebook defines this performance level as “ACCEPTABLE – better than no model, room to improve” for clinical readmission prediction. 

## Feature Importance and Interpretability

Using SHAP `TreeExplainer` on a sample of test data, the top contributors (by mean absolute SHAP value) are: 

- `number_inpatient` – count of prior inpatient visits.  
- `age_ord` – age band.  
- `num_lab_procedures` – lab intensity.  
- `prior_visits_total` – any prior healthcare utilization.  
- `number_diagnoses` – comorbidity complexity.  
- `time_in_hospital` – length of stay.  
- `num_medications` – medication burden.  
- `has_prior_inpatient` – prior hospitalization flag.  
- `race_idx` – encoded race.  
- `diag1cat_idx` – primary diagnosis category.  

These align with expectations from the Strack et al. study, where prior utilization, comorbid burden, and management intensity correlate with readmission outcomes. 

## Limitations and Improvement Ideas

Limitations:

- The model is trained on retrospective data from a specific set of US hospitals (1999–2008), which may not fully reflect current practice patterns. 
- Important social determinants of health and outpatient follow‑up quality are not directly captured in the dataset. 
- Some clinically important columns (e.g., `medical_specialty`, `payer_code`) have high missingness, limiting their predictive power. 

Potential future improvements:

- Hyperparameter optimization (e.g., Bayesian search on learning rate, depth, regularization, and sampling ratios).  
- Alternative algorithms: LightGBM, CatBoost, or calibrated logistic regression as an interpretable baseline.  
- Better handling of calibration and decision thresholds to match operational constraints.  
- Building separate models by primary diagnosis group (e.g., diabetes vs circulatory vs respiratory) as in the original logistic regression analysis. 
- Incorporating temporal patterns of prior visits rather than simple counts.

The current baseline establishes a solid, extensible foundation for 30‑day readmission risk modeling within Microsoft Fabric. 