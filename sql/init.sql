-- Cagridge Gas Stations Database Schema
-- Initial setup for Texas locations

-- Schema for each location
CREATE SCHEMA IF NOT EXISTS houston;
CREATE SCHEMA IF NOT EXISTS dallas;
CREATE SCHEMA IF NOT EXISTS austin;
CREATE SCHEMA IF NOT EXISTS san_antonio;
CREATE SCHEMA IF NOT EXISTS analytics;

-- Store/Station Information
CREATE TABLE IF NOT EXISTS analytics.stations (
    station_id SERIAL PRIMARY KEY,
    station_name VARCHAR(100) NOT NULL,
    location VARCHAR(50) NOT NULL,
    address TEXT,
    city VARCHAR(50),
    state VARCHAR(2) DEFAULT 'TX',
    zip_code VARCHAR(10),
    lat DECIMAL(10, 8),
    lon DECIMAL(11, 8),
    opened_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fuel Sales Transactions
CREATE TABLE IF NOT EXISTS analytics.fuel_sales (
    sale_id SERIAL PRIMARY KEY,
    station_id INTEGER REFERENCES analytics.stations(station_id),
    transaction_date TIMESTAMP NOT NULL,
    fuel_type VARCHAR(20) NOT NULL, -- Regular, Premium, Diesel
    gallons DECIMAL(10, 3) NOT NULL,
    price_per_gallon DECIMAL(6, 3) NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(20), -- Cash, Credit, Debit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Store/Convenience Store Sales
CREATE TABLE IF NOT EXISTS analytics.store_sales (
    sale_id SERIAL PRIMARY KEY,
    station_id INTEGER REFERENCES analytics.stations(station_id),
    transaction_date TIMESTAMP NOT NULL,
    product_category VARCHAR(50), -- Snacks, Beverages, Tobacco, etc.
    product_name VARCHAR(100),
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(8, 2) NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory Management
CREATE TABLE IF NOT EXISTS analytics.inventory (
    inventory_id SERIAL PRIMARY KEY,
    station_id INTEGER REFERENCES analytics.stations(station_id),
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    current_stock INTEGER NOT NULL,
    min_stock_level INTEGER,
    max_stock_level INTEGER,
    unit_cost DECIMAL(8, 2),
    last_restocked TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fuel Inventory
CREATE TABLE IF NOT EXISTS analytics.fuel_inventory (
    fuel_inventory_id SERIAL PRIMARY KEY,
    station_id INTEGER REFERENCES analytics.stations(station_id),
    fuel_type VARCHAR(20) NOT NULL,
    tank_capacity DECIMAL(12, 2),
    current_level DECIMAL(12, 2),
    last_delivery_date TIMESTAMP,
    last_delivery_gallons DECIMAL(12, 2),
    next_delivery_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Employee Information
CREATE TABLE IF NOT EXISTS analytics.employees (
    employee_id SERIAL PRIMARY KEY,
    station_id INTEGER REFERENCES analytics.stations(station_id),
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    position VARCHAR(50),
    hire_date DATE,
    hourly_rate DECIMAL(6, 2),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Employee Shifts
CREATE TABLE IF NOT EXISTS analytics.employee_shifts (
    shift_id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES analytics.employees(employee_id),
    station_id INTEGER REFERENCES analytics.stations(station_id),
    shift_date DATE NOT NULL,
    clock_in TIMESTAMP,
    clock_out TIMESTAMP,
    hours_worked DECIMAL(5, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Customer Loyalty Program
CREATE TABLE IF NOT EXISTS analytics.loyalty_customers (
    customer_id SERIAL PRIMARY KEY,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    signup_date DATE,
    points_balance INTEGER DEFAULT 0,
    tier VARCHAR(20) DEFAULT 'Bronze', -- Bronze, Silver, Gold, Platinum
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Gas stations
INSERT INTO analytics.stations (station_name, location, address, city, zip_code, lat, lon, opened_date) VALUES
('Cagridge Houston Main', 'Houston', '1234 Main St', 'Houston', '77002', 29.7604, -95.3698, '2020-01-15'),
('Cagridge Dallas Central', 'Dallas', '5678 Central Ave', 'Dallas', '75201', 32.7767, -96.7970, '2020-03-20'),
('Cagridge Austin Downtown', 'Austin', '9012 Congress Ave', 'Austin', '78701', 30.2672, -97.7431, '2020-06-10'),
('Cagridge San Antonio Plaza', 'San Antonio', '3456 Commerce St', 'San Antonio', '78205', 29.4241, -98.4936, '2020-09-05');

-- Indexes for better query performance
CREATE INDEX idx_fuel_sales_station ON analytics.fuel_sales(station_id);
CREATE INDEX idx_fuel_sales_date ON analytics.fuel_sales(transaction_date);
CREATE INDEX idx_store_sales_station ON analytics.store_sales(station_id);
CREATE INDEX idx_store_sales_date ON analytics.store_sales(transaction_date);
CREATE INDEX idx_inventory_station ON analytics.inventory(station_id);
CREATE INDEX idx_fuel_inventory_station ON analytics.fuel_inventory(station_id);
CREATE INDEX idx_employees_station ON analytics.employees(station_id);
CREATE INDEX idx_shifts_employee ON analytics.employee_shifts(employee_id);
CREATE INDEX idx_shifts_date ON analytics.employee_shifts(shift_date);

-- View for daily sales summary
CREATE OR REPLACE VIEW analytics.daily_sales_summary AS
SELECT 
    s.station_name,
    s.location,
    DATE(fs.transaction_date) as sale_date,
    SUM(fs.gallons) as total_gallons_sold,
    SUM(fs.total_amount) as total_fuel_revenue,
    COALESCE(SUM(ss.total_amount), 0) as total_store_revenue,
    SUM(fs.total_amount) + COALESCE(SUM(ss.total_amount), 0) as total_revenue
FROM analytics.stations s
LEFT JOIN analytics.fuel_sales fs ON s.station_id = fs.station_id
LEFT JOIN analytics.store_sales ss ON s.station_id = ss.station_id 
    AND DATE(fs.transaction_date) = DATE(ss.transaction_date)
GROUP BY s.station_name, s.location, DATE(fs.transaction_date)
ORDER BY sale_date DESC, s.location;

-- Key-value table for dashboard metrics
CREATE TABLE IF NOT EXISTS analytics.dashboard_metrics (
    metric_name VARCHAR(100) PRIMARY KEY,
    metric_value VARCHAR(255),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Default values for the dashboard
INSERT INTO analytics.dashboard_metrics (metric_name, metric_value, updated_at)
VALUES
    ('etl_last_run', 'Pending', '1970-01-01 00:00:00'),
    ('etl_fuel_count', '0', '1970-01-01 00:00:00'),
    ('etl_store_count', '0', '1970-01-01 00:00:00'),
    ('etl_next_run', 'Not Scheduled', '1970-01-01 00:00:00'),
    ('inv_last_run', 'Pending', '1970-01-01 00:00:00'),
    ('inv_fuel_alerts', '0', '1970-01-01 00:00:00'),
    ('inv_stock_alerts', '0', '1970-01-01 00:00:00'),
    ('dbt_last_run', 'Pending', '1970-01-01 00:00:00'),
    ('dbt_staging_models', '0', '1970-01-01 00:00:00'),
    ('dbt_mart_models', '0', '1970-01-01 00:00:00'),
    ('dbt_tests', '0', '1970-01-01 00:00:00')
ON CONFLICT (metric_name) DO NOTHING;