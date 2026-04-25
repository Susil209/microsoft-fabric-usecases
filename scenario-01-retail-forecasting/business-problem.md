# Business Problem – Retail Demand Forecasting

Right now, your store managers are using last week's Excel report to make today's stocking decisions. That means you're always one step behind. With Microsoft Fabric, we connect your raw daily sales data, run it through a machine learning model trained on your own 3-year history, and deliver a live dashboard every morning at 6 am — before managers even arrive. When a product is predicted to sell out, the system emails the store manager and procurement automatically. No reports to run. No formulas to check. The data works for you.

## Points to consider

- Frequent stockouts on fast-moving items, leading to lost sales and poor customer experience
- Overstock on slow-moving items, tying up working capital and increasing waste
- Limited visibility of the impact of holidays, promotions, and seasonality on demand
- Fragmented data across systems, making it hard to build and maintain forecasting models

## Desired outcomes

- Accurate short-term and medium-term forecasts of daily sales by store and product family
- Clear view of which items are at risk of stockout or overstock in the next days/weeks
- Ability for planners and category managers to adjust orders and promotions early
- A single, governed analytics environment that connects raw data, models, and dashboards

## Why Microsoft Fabric

- **Single data foundation (OneLake + Lakehouse):** All Kaggle CSVs (sales, stores, items, promotions, holidays, oil prices) are ingested once into OneLake and modeled in a Lakehouse instead of being copied across tools.
- **Unified engineering, ML, and BI:** Data engineers, data scientists, and analysts all work in the same Fabric workspace on the same tables, using notebooks and Power BI without exporting data to other platforms.
- **Real-time analytics ready:** Real-Time Analytics/KQL databases can ingest POS and online order streams, allowing near real-time monitoring of sales spikes and how they deviate from forecasts.
- **Governance and monitoring:** Pipelines, notebooks, models, and reports are governed in one place, with lineage, access control, and run history suitable for production use.
