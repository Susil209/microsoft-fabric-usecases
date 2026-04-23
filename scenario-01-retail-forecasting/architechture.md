# Architecture – Scenario 01 Retail Forecasting

## Overview

This use case implements a retail demand forecasting solution in Microsoft Fabric using the Kaggle Store Sales dataset. The objective is to ingest raw files into a Lakehouse, clean and model them into Silver tables, create ML-ready feature tables, and later use them for forecasting and reporting.

## Fabric components used

- **Workspace** – central place for all scenario artifacts
- **OneLake / Lakehouse** – stores raw files and Delta tables
- **Notebook (Data Engineering)** – transforms Bronze tables into Silver tables and feature tables
- **Data Pipeline** – will orchestrate notebook execution on a schedule
- **Power BI in Fabric** – will later consume curated tables for dashboarding

## Data flow

1. Kaggle CSV files are uploaded into the Lakehouse Files area.
2. Raw files are loaded into Bronze Delta tables.
3. A notebook (`nb_s1_build_silver`) cleans and transforms Bronze data into Silver tables.
4. A second notebook (`nb_s1_build_features`) joins Silver tables and creates the ML feature table `fact_store_item_features`.
5. A Data Pipeline (`pl_s1_prepare_data`) will run the notebooks in sequence on a schedule.
6. Curated tables will later be used for model training and Power BI reporting.

## Data Layers

### Bronze
Raw data loaded from Kaggle CSV files into Lakehouse tables.

Examples:
- `bronze_train_sales`
- `bronze_test_sales`
- `bronze_stores`
- `bronze_oil_prices`
- `bronze_holidays_events`
- `bronze_transactions`

### Silver
Cleaned, typed, analytics-friendly tables created from Bronze tables.

Created tables:
- `silver_sales_daily`
- `silver_store_dim`
- `silver_item_dim`
- `silver_calendar_dim`

### Feature
ML-ready table created by joining Silver tables and adding time-series features.

Planned / in progress:
- `fact_store_item_features`

Features included:
- Lag sales values (1, 7, 14, 28)
- Moving averages (7, 14, 28)
- Promotion flag
- Holiday flag
- Store and calendar attributes

## Current status

- Bronze ingestion completed
- Silver tables created successfully
- Feature notebook created and being refined
- Data Pipeline and model training are pending