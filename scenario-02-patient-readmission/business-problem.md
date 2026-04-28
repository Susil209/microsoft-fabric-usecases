# Business Problem: 30‑Day Readmission in Diabetic Inpatients

## Context

Patients with diabetes have a high risk of complications and unplanned readmissions, which drive significant cost and burden for health systems.
In the US, value‑based payment and penalty programs increasingly tie hospital reimbursement to avoidable readmission rates, especially within 30 days of discharge.

The Strack et al. study analyzed almost 70,000 diabetes‑related admissions across 54 hospitals over 10 years, showing that HbA1c testing and attention to diabetes management are associated with differences in readmission patterns.
This project operationalizes similar insights in a Microsoft Fabric environment to support real‑time or near‑real‑time risk stratification for current inpatients.

## Problem Statement

> For adult inpatients with a diagnosis of diabetes at discharge, predict whether the patient will be readmitted within 30 days of discharge.

We treat this as a binary classification problem where the target `readmitted_30d` is 1 for readmission within 30 days and 0 otherwise (including no readmission or readmission after 30 days).
The dataset exhibits strong class imbalance, with only about 4.5 % of encounters leading to a 30‑day readmission, which makes naive accuracy misleading and requires careful handling in the model.

## Business Objectives

From a hospital/health‑system perspective, the solution should:

- **Identify high‑risk patients before discharge** so clinicians, case managers, and social workers can trigger interventions (education, follow‑up appointments, telehealth check‑ins, medication reconciliation). 
- **Reduce preventable 30‑day readmissions** in the diabetic population, improving quality metrics and reducing penalties and costs.
- **Surface modifiable risk factors** (length of stay, prior utilization, poor diabetes control signals, etc.) via explainability to guide quality‑improvement initiatives.

## Key Questions

1. Can we build a predictive model in Fabric that achieves *clinically useful* discrimination for 30‑day readmission risk in this dataset? 
2. Which factors (e.g., prior inpatient encounters, age, lab testing patterns, diagnosis clusters) are most strongly associated with readmission risk?
3. How can the model be integrated into discharge planning workflows and downstream tools (e.g., Power BI dashboards or custom scoring notebooks) within Microsoft Fabric?

## Success Criteria

### Technical

- 5‑fold cross‑validated AUC‑ROC ≥ 0.65 on the training data and similar performance on hold‑out test data, measured using stratified folds. 
- Robust handling of class imbalance (e.g., via `scale_pos_weight` in XGBoost) and stable performance across folds (low CV AUC standard deviation).

## How Microsoft Fabric Helps in This Use Case?

- Microsoft Fabric provides a **unified SaaS data and analytics platform**, so the entire pipeline—ingestion, cleaning, feature engineering, modeling, and reporting—runs in one governed workspace instead of being stitched together from multiple Azure services.
- The **Lakehouse + medallion architecture** pattern recommended for Fabric (bronze/silver/gold) fits naturally with the raw‑to‑features progression used in this project.
- For healthcare specifically, Fabric’s Lakehouse is designed to ingest and harmonize multi‑modal healthcare data (EHR, labs, claims, devices) into a single foundation for analytics and machine learning.
- Because Fabric is a **fully managed SaaS service**, teams don’t have to manage clusters, storage accounts, or complex security wiring between services.
- Finally, Fabric’s healthcare data solutions and lakehouse foundations are explicitly aimed at use cases like **care management analytics and high‑risk patient identification**, where models such as 30‑day readmission prediction become a core building block.