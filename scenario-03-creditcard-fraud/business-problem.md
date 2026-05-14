# Business-problem.md

# Scenario 04 — Real-Time Financial Fraud Detection

## Business Problem, Context & Fabric Solution

---

## The Business Problem

Credit card fraud costs the global payments industry over **billions of dollars
annually**. For an individual bank or payment processor, the cost is not
just the fraudulent transaction itself — it is the combination of
chargebacks, dispute resolution costs, customer compensation, reputational
damage, and regulatory penalties that follow.

The single most important factor in minimising fraud loss is **speed**.
The window to act is measured in seconds. Once a fraudulent transaction
is authorised and the card holder has been notified, the damage is done.
Every minute of delay between a fraud event and a block action increases
the probability that further fraud occurs on the same compromised card.

---

## Why Traditional Approaches Fail

### The batch report problem

Most fraud operations teams work like this today:

```
Transaction occurs at 02:14 AM
        ↓
Batch job runs at 06:00 AM
        ↓
Report lands in analyst inbox at 07:30 AM
        ↓
Analyst reviews and escalates at 09:00 AM
        ↓
Card blocked at 09:45 AM
        ↓
7+ hours elapsed — further fraud likely occurred
```

The card holder has already been charged. The money has already moved.
The fraudster has already cashed out or moved on to the next target.

### The rule-based system problem

Legacy fraud systems use static rules: flag any transaction over $1,000,
flag international transactions at unusual hours, flag mismatched billing
addresses. These rules have two fundamental weaknesses:

- **High false positive rate**: genuine high-value transactions trigger
  constantly, creating alert fatigue for fraud analysts.
- **Completely blind to new fraud patterns**: the moment fraudsters learn
  the rules, they transact below the thresholds. Rules require a human to
  discover the new pattern and manually update the logic — weeks later.

### The data silo problem

Transaction data, fraud labels, customer profiles, and device metadata
typically live in separate systems. Running a fraud model requires data
engineers to extract, join, and move data between platforms before any
analysis can begin. By the time the pipeline is ready, the fraud window
has closed.

---

## Dataset Context

**Source:** Credit Card Fraud Detection — Kaggle
**Transactions:** 284,807 over two days, September 2013

| Metric | Value |
|--------|-------|
| Total transactions | 284,807 |
| Fraudulent transactions | 492 |
| Fraud rate | 0.1727% |
| Class imbalance ratio | 1 : 578 |
| Amount range | $0.00 → $25,691.16 |
| Feature count | 31 (Time, V1–V28, Amount, Class) |

### The 0.17% challenge

This is the most extreme class imbalance across all five scenarios:

| Scenario | Positive rate | Imbalance |
|----------|--------------|-----------|
| 01 Retail | N/A (regression) | N/A |
| 02 Healthcare | 11.16% | 1:8 |
| **03 Fraud** | **0.17%** | **1:578** |

At 1:578, a naive model that predicts "not fraud" for every transaction
achieves **99.83% accuracy** while catching **zero fraud**. Standard
accuracy is a useless metric here. The imbalance is so extreme that
`class_weight='balanced'` alone is insufficient — SMOTE oversampling
is required to give the model enough fraud signal to learn from.

### Why V1–V28 have no names

The features V1 through V28 are the result of **PCA transformation**
applied by the dataset authors to protect cardholder confidentiality.
The original raw features (merchant category, terminal ID, cardholder
location, device fingerprint) cannot be disclosed. This is a critical
distinction from the other scenarios — **no domain-specific feature
engineering is possible**. The only raw features are `Time` and `Amount`.

---

## How Microsoft Fabric Solves It

### From hours to seconds

| Layer | Old approach | With Fabric |
|-------|-------------|-------------|
| Ingestion | Nightly batch ETL | Data Factory pipeline, delta tables |
| Feature engineering | Manual Python script, scheduled | Spark Notebook, automated |
| Model scoring | Run next morning | Batch: post-pipeline. Stream: within seconds |
| Alert delivery | Email report next day | Data Activator → Teams, <15 seconds |
| Card block | Manual analyst action | Power Automate automated flow |

### Dual-model architecture

Fabric hosts two fraud models in a single ML Experiment workspace:

**Isolation Forest** — learns what normal looks like (unsupervised).
Trained on legitimate transactions only. Flags statistical outliers
with no labelled fraud required. In production this catches novel
fraud patterns the supervised model has not yet learned.

**XGBoost + SMOTE** — learns explicit fraud patterns (supervised).
Trained on all labelled data with synthetic fraud oversampling.
Achieves AUC-ROC 0.9928 and Average Precision 0.8701 on the test set.
Precision of 94.47% confirmed in Power BI dashboard.

### Two-layer defence in production

```
BATCH layer (historical, runs daily):
  XGBoost scores all transactions
  CRITICAL tier: XGB ≥ 0.70
  Feeds: Power BI Pages 1-3, fraudWH, audit trail

STREAMING layer (live, runs continuously):
  Eventstream receives each transaction on arrival
  Isolation Forest flags statistical anomalies in real time
  KQL Database queryable within milliseconds
  Feeds: Power BI Page 4 (15-second refresh), Data Activator
```

### Unified platform — one workspace

All of the following run inside a single Fabric workspace
with no separate services, no data movement, no additional billing:

- Data Factory (ingestion)
- Spark Notebooks (cleaning, feature engineering, ML)
- ML Experiment + MLflow (model tracking, registration)
- Lakehouse + OneLake (all Delta tables)
- Eventstream (real-time stream routing)
- KQL Database (millisecond query layer)
- Fabric Warehouse (Gold layer SQL)
- Power BI (batch + live dashboards)
- Data Activator (automated alerts + card block trigger)

---

## Business Value Delivered

### Confirmed from Power BI dashboard

| Metric | Value | Source |
|--------|-------|--------|
| Fraud detection rate | 85.7% (test set) | XGBoost @ threshold 0.70 |
| CRITICAL tier precision | **94.47%** | Power BI Page 1 |
| False positive rate | **5.53%** | Power BI Page 3 |
| Amount at risk flagged | **$51,240** | Power BI Page 1 |
| CRITICAL transactions flagged | **506** | Power BI Page 1 |
| Peak fraud hour identified | **Hour 2 (2am)** | Power BI Page 2 |
| Night vs day fraud rate | 0.31% vs 0.14% | Power BI Page 2 |
| Live alert latency | **< 15 seconds** | Data Activator + Teams |
| BLOCK_NOW automation | $529 transaction blocked | Power BI Page 4 live table |

### What fabric solves?

> *"Today your fraud team finds out about a compromised card the next
> morning when the report lands in their inbox — by then the fraudster
> has moved on. With Microsoft Fabric, every transaction is scored by
> a machine learning model as it arrives: high-confidence fraud above
> $500 triggers an automated card block within 15 seconds, with no
> human in the loop. Everything runs inside one workspace, one billing
> unit, with a live dashboard that your fraud analysts can watch update
> in real time."*

---
