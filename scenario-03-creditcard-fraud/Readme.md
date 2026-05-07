# Scenario 04 — Real-Time Financial Fraud Detection

**Industry:** Finance / Payments  
**Dataset:** [Credit Card Fraud Detection — Kaggle](https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud) (284,807 transactions, 492 fraud)  
**Lakehouse:** lh_fraud | **Workspace:** FraudDetectionAnalysis

---

## Business Problem

Credit card fraud costs the global payments industry over $32 billion annually.
The window to act is measured in seconds — not hours. By the time a batch model
runs overnight, the fraudster has moved on. The detection must be real-time.

## About Dataset

### Context

It is important that credit card companies are able to recognize fraudulent credit card transactions so that customers are not charged for items that they did not purchase.

### Content

The dataset contains transactions made by credit cards in September 2013 by European cardholders.
This dataset presents transactions that occurred in two days, where we have 492 frauds out of 284,807 transactions. The dataset is highly unbalanced, the positive class (frauds) account for 0.172% of all transactions.

It contains only numerical input variables which are the result of a PCA transformation. Unfortunately, due to confidentiality issues, we cannot provide the original features and more background information about the data. Features V1, V2, … V28 are the principal components obtained with PCA, the only features which have not been transformed with PCA are 'Time' and 'Amount'. Feature 'Time' contains the seconds elapsed between each transaction and the first transaction in the dataset. The feature 'Amount' is the transaction Amount, this feature can be used for example-dependant cost-sensitive learning. Feature 'Class' is the response variable and it takes value 1 in case of fraud and 0 otherwise.

Given the class imbalance ratio, we recommend measuring the accuracy using the Area Under the Precision-Recall Curve (AUPRC). Confusion matrix accuracy is not meaningful for unbalanced classification.

---

## Dataset

- **284,807** transactions over two days in September 2013
- **492 fraud cases** — 0.17% positive rate (1:578 imbalance)
- Features V1–V28: PCA-transformed for confidentiality. No feature names available.
- Features Time and Amount: raw values
- Target: Class (1 = fraud, 0 = legitimate)
