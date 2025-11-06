-- Staging model for stations
-- Creates a cleaned view of station master data

{{ config(
    materialized='view',
    schema='staging'
) }}

select
    station_id,
    station_name,
    location,
    address,
    city,
    state,
    zip_code,
    lat,
    lon,
    opened_date,
    is_active,
    created_at,
    updated_at
from {{ source('analytics', 'stations') }}
