-- Staging model for store sales
-- This model cleans and standardizes store sales data from PostgreSQL

WITH source_data AS (
    SELECT
        sale_id,
        station_id,
        transaction_date,
        product_category,
        product_name,
        quantity,
        unit_price,
        total_amount,
        payment_method,
        created_at
    FROM {{ source('analytics', 'store_sales') }}
),

cleaned_data AS (
    SELECT
        sale_id,
        station_id,
        transaction_date,
        UPPER(TRIM(product_category)) AS product_category,
        TRIM(product_name) AS product_name,
        quantity,
        ROUND(unit_price, 2) AS unit_price,
        ROUND(total_amount, 2) AS total_amount,
        UPPER(TRIM(payment_method)) AS payment_method,
        created_at,
        DATE(transaction_date) AS transaction_date_key,
        EXTRACT(YEAR FROM transaction_date) AS transaction_year,
        EXTRACT(MONTH FROM transaction_date) AS transaction_month,
        EXTRACT(DAY FROM transaction_date) AS transaction_day
    FROM source_data
    WHERE quantity > 0
      AND total_amount > 0
      AND transaction_date IS NOT NULL
)

SELECT * FROM cleaned_data
