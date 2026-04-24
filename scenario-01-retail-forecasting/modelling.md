# Modeling – Scenario 01 Retail Forecasting

## Feature list

| Feature | Type | Description |
|---------|------|-------------|
| `store_nbr` | Numeric | Store identifier |
| `item_id` | Numeric (encoded) | Product family identifier |
| `family` | Categorical (encoded) | Product category name |
| `onpromotion` | Binary | Items on promotion that day |
| `is_holiday` | Binary | Whether the date is a holiday/event |
| `year` | Numeric | Calendar year |
| `month` | Numeric | Calendar month |
| `day_of_week` | Numeric | Day of week (0=Mon to 6=Sun) |
| `city` | Categorical (encoded) | Store city |
| `state` | Categorical (encoded) | Store state |
| `store_type` | Categorical (encoded) | Store type classification |
| `cluster` | Numeric | Store cluster group |
| `lag_1` | Numeric | Sales 1 day ago |
| `lag_7` | Numeric | Sales 7 days ago |
| `lag_14` | Numeric | Sales 14 days ago |
| `lag_28` | Numeric | Sales 28 days ago |
| `ma_7` | Numeric | 7-day moving average |
| `ma_14` | Numeric | 14-day moving average |
| `ma_28` | Numeric | 28-day moving average |

## Model choice

- **Algorithm:** LightGBM (tree-based gradient boosting regressor)
- **Rationale:** LightGBM handles tabular time-series features (lag, MA, categorical context) effectively and trains quickly on large row counts. It does not require normalization and is standard in Kaggle retail forecasting solutions. It also provides interpretable feature importances.
- **Approach:** Single global model trained across all stores and product families, using store/item identifiers as features.
- **Validation strategy:** Time-based split — last 28 days as validation, all earlier data as training. Random split would cause data leakage in time-series forecasting.


## Metrics

| Run | Model | val_RMSE | val_MAPE | Notes |
|-----|-------|----------|----------|-------|
| Run 01 | LightGBM baseline | 208.89 | 0.354 | Global model, no tuning, 28-day validation split |

Metric stored in the `retail-demand-forecasting-s01` MLflow experiment in the Fabric workspace for all logged runs, parameters, and metric history.

## MLflow tracking

- Experiment name: `retail-demand-forecasting-s01`
- Registered model: `retail-demand-lgbm-s01`
- Forecast output table: `fact_store_item_forecast`
- Columns: `date`, `store_nbr`, `item_id`, `family`, `forecast_qty`, `actual_sales`, `model_run_id`, `model_name`, `created_at`