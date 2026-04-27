# Scenario-2 Healthcare Patient Readmission Prediction with Microsoft Fabric

This project uses Microsoft Fabric Lakehouse, PySpark, and XGBoost to predict 30‑day hospital readmission risk for patients with diabetes, based on the widely used Strack et al. “Diabetic Hospital Readmission” dataset (Kaggle/UCI).
The end‑to‑end pipeline follows a bronze–silver–feature–ML pattern inside a Fabric workspace, from raw CSV ingestion to a registered MLflow model ready for scoring.

## Scenario

Hospitals face financial penalties and quality‑of‑care pressure around unplanned readmissions, particularly for chronic conditions such as diabetes.
The goal of this project is to proactively identify inpatients with diabetes who are at high risk of being readmitted within 30 days, so that care teams can intervene (e.g., education, medication optimization, follow‑up scheduling).

## Dataset

- [Source: Kaggle – “Diabetes 130‑US hospitals for years 1999–2008” (Strack et al.).](https://www.kaggle.com/datasets/brandao/diabetes)
- Original scope: 101,766 inpatient encounters for patients with diabetes, with 50 raw columns in the uploaded CSV (`diabetic_data.csv`).
- After cleaning and deduplication, the modeling dataset contains 71,518 unique patients (one most‑recent encounter per patient).

Key characteristics (after silver cleaning):

- Inpatient stays between 1 and 14 days that did not end in hospice or death.
- Readmission label derived from the original `readmitted` column, focusing on “readmitted within 30 days” vs. “30 or more days / no readmission”.
- Strong class imbalance: only about 4.5 % of encounters are followed by a 30‑day readmission.

## Technical Stack

- **Platform:** Microsoft Fabric Workspace `PatientReadmissionPrediction` and Lakehouse `lh_healthcare_readmission`.  
- **Storage:** Delta tables for bronze (`bronze_encounters`), silver (`silver_encounters_clean`), and feature (`silver_features`) layers.
- **Compute:** Fabric notebooks using the `synapsepyspark` kernel for PySpark and Python.
- **ML & tracking:** XGBoost (`XGBClassifier`) and MLflow experiment `HospitalReadmission30Day` with registered model `HospitalReadmission30d`.

## Pipeline Overview

1. **Bronze ingestion** – Load `diabetic_data.csv` from Lakehouse Files into a bronze Delta table, fixing invalid column names.
2. **Silver cleaning** – Handle missing values, drop unusable columns, cast numeric types, deduplicate to one encounter per patient, and derive a binary `readmitted_30d` label.
3. **Feature engineering** – Build clinically meaningful features from diagnoses (ICD‑9 groups), lab results (HbA1c, glucose), medication changes, and prior utilization, then encode categoricals and persist `silver_features`.
4. **Model experiment** – Train an XGBoost classifier with class‑imbalance handling and 5‑fold stratified cross‑validation; log metrics and artifacts to MLflow and register the model.

## Model Performance (Current Baseline)

- 5‑fold CV AUC‑ROC: 0.6433 ± 0.0074.
- Hold‑out test AUC‑ROC: 0.6647.
- Average precision (PR‑AUC): 0.0942 with a decision threshold of 0.35 on the positive class.

This is an *acceptable* baseline for a highly imbalanced clinical readmission problem and leaves room for further feature and model improvements.

## Repository Layout

Suggested structure for this project:

- `README.md` – High‑level overview and quickstart.  
- `business-problem.md` – Clinical and business framing of the use case.  
- `architecture.md` – Microsoft Fabric and Lakehouse architecture.  
- `implementation-steps.md` – Notebook‑by‑notebook implementation guide.  
- `modeling.md` – Detailed modeling, features, and evaluation.  
- `2026-04-27.md` – Experiment log and notes for this run.  
- `01-Load_Bronze_Table.ipynb` – Bronze load.
- `02_silver_cleaning.py.ipynb` – Silver cleaning.  
- `03_feature_engineering.py.ipynb` – Feature engineering.
- `04_ml_experiment.py.ipynb` – ML experiment and MLflow logging.

## References

- Strack, B. et al., “Impact of HbA1c Measurement on Hospital Readmission Rates: Analysis of 70,000 Clinical Database Patient Records,” *BioMed Research International*, 2014.