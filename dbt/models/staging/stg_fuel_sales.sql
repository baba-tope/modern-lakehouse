-- Staging model for fuel sales
-- This model cleans and standardizes fuel sales data from PostgreSQL

WITH source_data AS (
    SELECT
        sale_id,
        station_id,
        transaction_date,
        fuel_type,
        gallons,
        price_per_gallon,
        total_amount,
        payment_method,
        created_at
    FROM {{ source('analytics', 'fuel_sales') }}
),

cleaned_data AS (
    SELECT
        sale_id,
        station_id,
        transaction_date,
        UPPER(TRIM(fuel_type)) AS fuel_type,
        ROUND(gallons, 3) AS gallons,
        ROUND(price_per_gallon, 3) AS price_per_gallon,
        ROUND(total_amount, 2) AS total_amount,
        UPPER(TRIM(payment_method)) AS payment_method,
        created_at,
        DATE(transaction_date) AS transaction_date_key,
        EXTRACT(YEAR FROM transaction_date) AS transaction_year,
        EXTRACT(MONTH FROM transaction_date) AS transaction_month,
        EXTRACT(DAY FROM transaction_date) AS transaction_day,
        EXTRACT(HOUR FROM transaction_date) AS transaction_hour
    FROM source_data
    WHERE gallons > 0
      AND total_amount > 0
      AND transaction_date IS NOT NULL
)

SELECT * FROM cleaned_data
