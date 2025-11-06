-- Daily sales summary by station
-- Aggregates fuel and store sales by day and station

{{ config(
    materialized='table',
    schema='mart'
) }}

with fuel_daily as (
    select
        station_id,
        transaction_date_key as sale_date,
        sum(gallons) as total_gallons,
        sum(total_amount) as fuel_revenue,
        count(distinct sale_id) as fuel_transaction_count
    from {{ ref('stg_fuel_sales') }}
    group by station_id, transaction_date_key
),

store_daily as (
    select
        station_id,
        transaction_date_key as sale_date,
        sum(quantity) as total_items_sold,
        sum(total_amount) as store_revenue,
        count(distinct sale_id) as store_transaction_count
    from {{ ref('stg_store_sales') }}
    group by station_id, transaction_date_key
),

combined as (
    select
        coalesce(f.station_id, s.station_id) as station_id,
        coalesce(f.sale_date, s.sale_date) as sale_date,
        coalesce(f.total_gallons, 0) as total_gallons,
        coalesce(f.fuel_revenue, 0) as fuel_revenue,
        coalesce(f.fuel_transaction_count, 0) as fuel_transaction_count,
        coalesce(s.total_items_sold, 0) as total_items_sold,
        coalesce(s.store_revenue, 0) as store_revenue,
        coalesce(s.store_transaction_count, 0) as store_transaction_count,
        coalesce(f.fuel_revenue, 0) + coalesce(s.store_revenue, 0) as total_revenue,
        coalesce(f.fuel_transaction_count, 0) + coalesce(s.store_transaction_count, 0) as total_transactions
    from fuel_daily f
    full outer join store_daily s
        on f.station_id = s.station_id
        and f.sale_date = s.sale_date
)

select
    st.location,
    st.station_name,
    c.sale_date,
    c.total_gallons,
    c.fuel_revenue,
    c.fuel_transaction_count,
    c.total_items_sold,
    c.store_revenue,
    c.store_transaction_count,
    c.total_revenue,
    c.total_transactions
from combined c
join {{ ref('stg_stations') }} st on c.station_id = st.station_id