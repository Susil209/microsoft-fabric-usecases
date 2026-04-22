# Implementation Steps – Scenario 01 Retail Forecasting

This is the planned end-to-end implementation in Microsoft Fabric. Starting from 2026-04-23.

## Phase 0 – Setup

1. Create a Fabric workspace for the retail use case.
2. Create a Lakehouse `lh_retail_favorita`.
3. Download Kaggle Store Sales – Time Series Forecasting dataset locally.
4. Confirm local Git repo and VS Code setup for documentation.

## Phase 1 – Ingestion (Bronze)

1. Upload Kaggle CSVs (train, stores, items, holidays, oil, etc.) into the Lakehouse Files.
2. Load each file into raw Delta tables (e.g., `bronze_sales_raw`, `bronze_stores_raw`).
3. Validate row counts, column types, and basic data quality.

## Phase 2 – Modeling & Feature Engineering (Silver/Gold)

1. Create cleaned tables:
   - `sales_daily`
   - `store_dim`
   - `item_dim`
   - `calendar_dim`
2. Build a feature table at store–item–date level with:
   - Historical sales lags and moving averages
   - Promotion flags and holiday indicators
3. Store features in `fact_store_item_features`.

## Phase 3 – Model Training

1. Use a Fabric Data Science notebook on the Lakehouse to:
   - Load `fact_store_item_features`
   - Split into train/validation by time
   - Train a forecasting model (e.g., tree-based regression / forecasting library)
2. Log metrics and model artifacts using Fabric’s ML capabilities.
3. Write forecasts to `fact_store_item_forecast`.

## Phase 4 – Pipelines & Refresh

1. Create a Data Pipeline to:
   - Refresh raw and transformed tables
   - Run training/scoring notebooks on a schedule
2. Ensure forecasts are refreshed regularly (e.g., daily or weekly).

## Phase 5 – Reporting

1. Build a Power BI report in Fabric using Lakehouse / Warehouse tables.
2. Include:
   - Forecast vs actual sales by store and product family
   - Items at risk of stockout or overstock in the next horizon
   - Promotion and holiday impact views
3. Share the report with stakeholders and prepare a short demo script.

## Phase 6 – Real-Time Extension

1. Create a KQL database to ingest simulated POS events.
2. Join live sales streams with forecast data to monitor deviations and spikes.
3. Build a simple real-time dashboard if capacity allows.