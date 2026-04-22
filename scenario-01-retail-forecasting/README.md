# Scenario 01 – Retail Demand Forecasting & Inventory Optimization

This scenario uses Microsoft Fabric and a Kaggle retail sales dataset to forecast store–SKU demand and support better inventory and replenishment decisions.

## Goal

Reduce stockouts and excess inventory by forecasting daily demand at store–SKU level and exposing the forecasts to business users through dashboards.

## Dataset

- Source: Kaggle – Store Sales – Time Series Forecasting (Corporación Favorita) 
- [Kaggle – Store Sales](https://www.kaggle.com/competitions/store-sales-time-series-forecasting/data)
- Granularity: Daily sales by store and product family, with promotions and calendar/holiday data.

## Fabric components

- OneLake + Lakehouse for central storage of raw Kaggle CSVs
- Data Engineering (notebooks / SQL) for ingestion and transformations
- Data Science notebooks for demand forecasting model training and scoring
- Pipelines for scheduled refresh and scoring
- Power BI in Fabric for reports and KPIs
- (Optional) Real-Time Analytics/KQL DB for streaming POS/online events

## Status

- Business problem defined
- High-level Fabric solution approach documented
- Git + VS Code setup completed
- Fabric implementation starts from 2026-04-23
