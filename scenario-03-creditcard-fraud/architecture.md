# architecture.md
# Scenario 04 — Real-Time Financial Fraud Detection
## Microsoft Fabric End-to-End Architecture

---

## Overview

Scenario 04 introduces two capabilities not used in Scenarios 01–02:
**real-time streaming** via Eventstream + KQL Database, and
**unsupervised anomaly detection** via Isolation Forest alongside a
supervised XGBoost classifier. The result is a dual-layer fraud defence
system that catches both known fraud patterns and novel ones — with alerts
firing in under 15 seconds.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MICROSOFT FABRIC WORKSPACE                       │
│                    RetailAnalytics-POC                              │
│                                                                     │
│  ┌─────────────┐   ┌──────────────────────────────────────────┐   │
│  │   KAGGLE    │   │          LAKEHOUSE: lh_fraud              │   │
│  │  CSV File   │──▶│  Files/bronze/raw/creditcard.csv         │   │
│  │ 284,807 txn │   └──────────────────────────────────────────┘   │
│  └─────────────┘                    │                              │
│                                     ▼                              │
│                    ┌─────────────────────────────┐                │
│                    │   DATA FACTORY PIPELINE     │                │
│                    │   01_BronzeIngestion        │                │
│                    │   CSV → Delta table         │                │
│                    └────────────┬────────────────┘                │
│                                 ▼                                  │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                  🥉 BRONZE LAYER                             │ │
│  │   bronze_transactions  (284,807 rows, 31 columns)            │ │
│  │   Time | V1…V28 | Amount | Class                            │ │
│  └──────────────────────────────────┬───────────────────────────┘ │
│                                     ▼                              │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                  🥈 SILVER LAYER                             │ │
│  │                                                              │ │
│  │   02_silver_cleaning.py                                      │ │
│  │   ├── Cast V1-V28, Amount to Float                          │ │
│  │   ├── Extract hour_of_day from Time                         │ │
│  │   ├── Create amount_bin (zero/micro/small/medium/large)      │ │
│  │   └── StandardScaler on Amount + hour_of_day                │ │
│  │                    ↓                                         │ │
│  │   silver_features  (284,807 rows, 32 columns)                │ │
│  │                    ↓                                         │ │
│  │   03_isolation_forest.py          04_xgboost_fraud.py        │ │
│  │   ├── Train on 284,315 legit      ├── SMOTE: 0.17% → 9.09%  │ │
│  │   ├── Contamination: 0.002        ├── XGBoost n_est=500      │ │
│  │   ├── AUC: 0.9478                 ├── AUC: 0.9928            │ │
│  │   └── Registered: FraudIF v1     └── Registered: FraudXGB v1│ │
│  │                    ↓                                         │ │
│  │   05_batch_scoring.py                                        │ │
│  │   ├── XGBoost score per transaction (0-100%)                 │ │
│  │   ├── Isolation Forest anomaly flag (0/1)                    │ │
│  │   ├── CRITICAL tier: XGB ≥ 0.70 (iso_flag stored only)      │ │
│  │   └── BLOCK_NOW: XGB ≥ 0.90 AND Amount ≥ $500               │ │
│  │                    ↓                                         │ │
│  │   silver_fraud_scores  (284,807 rows)                        │ │
│  │   Time | Amount | fraud_score_pct | iso_flag                 │ │
│  │   fraud_tier | action_required | actual_fraud                │ │
│  └──────────────────────────────────┬───────────────────────────┘ │
│                                     │                              │
│            ┌────────────────────────┤                             │
│            ▼                        ▼                             │
│  ┌──────────────────┐   ┌───────────────────────────────────┐    │
│  │  🥇 GOLD LAYER  │   │      REAL-TIME LAYER              │    │
│  │   fraudWH        │   │                                   │    │
│  │                  │   │   EVENTSTREAM                     │    │
│  │  dim_hour        │   │   FraudTransactionStream          │    │
│  │  dim_amount_tier │   │   Source: Custom App (CSV sim)    │    │
│  │  fact_txns       │   │          ↓                        │    │
│  │  agg_fraud_hour  │   │   KQL DATABASE                    │    │
│  │  agg_model_agmt  │   │   FraudKQL / FraudEventhouse      │    │
│  │  vw_crit_alerts  │   │   transactions_stream             │    │
│  └────────┬─────────┘   └────────────┬──────────────────────┘    │
│           │                          │                            │
│           ▼                          ▼                            │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                    SERVE LAYER                               │ │
│  │                                                              │ │
│  │  POWER BI DASHBOARD  ◄──── fraudWH (batch, Pages 1-3)      │ │
│  │                      ◄──── FraudKQL (live, Page 4, 15s)    │ │
│  │                                                              │ │
│  │  DATA ACTIVATOR (REFLEX)                                    │ │
│  │  Source: FraudKQL → transactions_stream                     │ │
│  │  Trigger: fraud_tier = CRITICAL AND Amount ≥ $100           │ │
│  │  Action 1: Teams alert → fraud-alerts channel               │ │
│  │  Action 2: Power Automate card block (BLOCK_NOW only)       │ │
│  └──────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Medallion Layer Reference

### 🥉 Bronze Layer

| Table | Rows | Source | Purpose |
|-------|------|--------|---------|
| `bronze_transactions` | 284,807 | creditcard.csv | Raw transactions, untouched source of truth |

### 🥈 Silver Layer

| Table | Rows | Built by | Purpose |
|-------|------|----------|---------|
| `silver_features` | 284,807 | `02_silver_cleaning.py` | Cleaned, engineered features for ML |
| `silver_fraud_scores` | 284,807 | `05_batch_scoring.py` | ML scores, tiers, action labels |

### 🥇 Gold Layer (fraudWH)

| Object | Type | Rows | Purpose |
|--------|------|------|---------|
| `dim_hour` | Dimension | 24 | Hour labels, risk bands |
| `dim_amount_tier` | Dimension | 5 | Amount range descriptions |
| `fact_transactions` | Fact table | 284,807 | Central analytical table |
| `agg_fraud_by_hour` | Aggregate | 24 | Fraud rate per hour for charts |
| `agg_model_agreement` | Aggregate | 4 | IF vs XGBoost catch analysis |
| `vw_critical_alerts` | Alert view | ~500 | Data Activator feed, Amount ≥ $100 |

### Real-Time Layer

| Component | Item | Purpose |
|-----------|------|---------|
| Eventstream | `FraudTransactionStream` | Routes live transactions to KQL |
| KQL Database | `FraudKQL` | Sub-second queryable transaction stream |
| KQL Functions | `fn_txns_last_5min`, `fn_fraud_rate_1hr`, `fn_critical_high_value`, `fn_block_now_30min` | Power BI live card data sources |

---

## Data Flow Summary

```
Kaggle CSV
→ Data Factory (bronze_transactions)
→ Spark cleaning + scaling (silver_features)
→ Isolation Forest [unsupervised, batch]
→ XGBoost + SMOTE [supervised, batch]
→ Ensemble scoring (silver_fraud_scores)
→ Gold SQL (fraudWH tables)
→ Eventstream simulation → FraudKQL
→ Power BI (batch pages 1-3 from fraudWH)
→ Power BI (live page 4 from FraudKQL, 15s refresh)
→ Data Activator → Teams + Power Automate
```

---

## New Fabric Capabilities in Scenario 04

| Capability | Item 
|-----------|------
| Eventstream | `FraudTransactionStream`
| KQL Database | `FraudKQL` 
| KQL Functions | 4 stored functions 
| Real-time Power BI | Page 4, 15-second refresh 
| Dual data source PBI | fraudWH + FraudKQL 
| Unsupervised ML | Isolation Forest 

---