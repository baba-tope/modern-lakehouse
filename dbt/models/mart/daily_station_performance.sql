-- Mart model for daily station performance
-- Aggregates sales data by station and day

{{
    config(
        materialized='table',
        schema='mart'
    )
}}

WITH fuel_sales AS (
    SELECT * FROM {{ ref('stg_fuel_sales') }}
),

store_sales AS (
    SELECT * FROM {{ ref('stg_store_sales') }}
),

stations AS (
    SELECT * FROM {{ ref('stg_stations') }}
),

daily_fuel AS (
    SELECT
        station_id,
        transaction_date_key,
        SUM(gallons) AS total_gallons,
        SUM(total_amount) AS fuel_revenue,
        COUNT(DISTINCT sale_id) AS fuel_transaction_count,
        AVG(price_per_gallon) AS avg_price_per_gallon
    FROM fuel_sales
    GROUP BY station_id, transaction_date_key
),

daily_store AS (
    SELECT
        station_id,
        transaction_date_key,
        SUM(total_amount) AS store_revenue,
        COUNT(DISTINCT sale_id) AS store_transaction_count,
        COUNT(DISTINCT product_category) AS unique_categories_sold
    FROM store_sales
    GROUP BY station_id, transaction_date_key
),

combined AS (
    SELECT
        s.station_name,
        s.location,
        s.city,
        COALESCE(df.transaction_date_key, ds.transaction_date_key) AS date,
        COALESCE(df.total_gallons, 0) AS total_gallons_sold,
        COALESCE(df.fuel_revenue, 0) AS fuel_revenue,
        COALESCE(df.fuel_transaction_count, 0) AS fuel_transactions,
        COALESCE(df.avg_price_per_gallon, 0) AS avg_fuel_price,
        COALESCE(ds.store_revenue, 0) AS store_revenue,
        COALESCE(ds.store_transaction_count, 0) AS store_transactions,
        COALESCE(ds.unique_categories_sold, 0) AS product_categories_sold,
        COALESCE(df.fuel_revenue, 0) + COALESCE(ds.store_revenue, 0) AS total_revenue
    FROM stations s
    LEFT JOIN daily_fuel df ON s.station_id = df.station_id
    LEFT JOIN daily_store ds ON s.station_id = ds.station_id
        AND df.transaction_date_key = ds.transaction_date_key
    WHERE s.is_active = true
)

SELECT
    *,
    CASE 
        WHEN total_revenue > 10000 THEN 'High'
        WHEN total_revenue > 5000 THEN 'Medium'
        ELSE 'Low'
    END AS revenue_tier
FROM combined
ORDER BY date DESC, total_revenue DESC
