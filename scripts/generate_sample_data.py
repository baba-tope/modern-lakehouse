# Sample Data Generator for Cagridge Gas Stations
# Run this after PostgreSQL is initialized

import os
import random
import math
from datetime import datetime, timedelta

try:
    import psycopg2
except ImportError:
    psycopg2 = None
    print("Warning: psycopg2 not installed. Install with: pip install psycopg2-binary")

try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = None
    print("Warning: python-dotenv not installed. Install with: pip install python-dotenv")

# Load environment variables from .env file
if load_dotenv:
    load_dotenv()

# Connection parameters (from .env)
# Use localhost for host access via NodePort
conn_params = {
    'host': 'localhost',  # Access via NodePort
    'port': int(os.getenv('POSTGRES_PORT', '30001')),
    'database': os.getenv('POSTGRES_DB'),
    'user': os.getenv('POSTGRES_USER'),
    'password': os.getenv('POSTGRES_PASSWORD')
}

# Load Configuration

# | Scaling Factor | Approx. Txns / Day / Station | Est. Monthly Data Size | Notes         |
# |----------------|------------------------------|------------------------|---------------|
# | 1.0            | ~250 - 450                   | ~50 MB                 | Very Low Load |
# | 10.0           | ~2,500 - 4,500               | ~500 MB                | Moderate Load |
# | 50.0           | ~12,500 - 22,500             | ~2.5 GB                | High Load     |
# | 100.0          | ~25,000 - 45,000             | ~5.0 GB                | Stress Test   |
SCALING_FACTOR = int(os.getenv('DATA_SCALING_FACTOR', '50'))

# Sample Data
fuel_types = ['Regular', 'Premium', 'Diesel']
payment_methods = ['Cash', 'Credit', 'Debit']
product_categories = ['Snacks', 'Beverages', 'Tobacco', 'Automotive', 'Food']

products = {
    'Snacks': ['Chips', 'Candy Bar', 'Cookies', 'Jerky', 'Nuts'],
    'Beverages': ['Soda', 'Water', 'Energy Drink', 'Coffee', 'Juice'],
    'Tobacco': ['Cigarettes', 'Vape', 'Cigars'],
    'Automotive': ['Oil', 'Windshield Fluid', 'Air Freshener'],
    'Food': ['Hot Dog', 'Pizza Slice', 'Sandwich', 'Burrito']
}

# Base daily averages per location (scaled by SCALING_FACTOR)
BASE_DAILY_AVERAGES = {
    'Houston': {'store': 5500.0, 'fuel': 3000.0},
    'Dallas': {'store': 5000.0, 'fuel': 2700.0},
    'Austin': {'store': 4200.0, 'fuel': 2300.0},
    'San Antonio': {'store': 3600.0, 'fuel': 2000.0},
}

# US Holidays 2025
HOLIDAYS_2025 = [
    datetime(2025, 1, 1),   # New Year's Day
    datetime(2025, 1, 20),  # MLK Day
    datetime(2025, 2, 17),  # Presidents Day
    datetime(2025, 5, 26),  # Memorial Day
    datetime(2025, 7, 4),   # Independence Day
    datetime(2025, 9, 1),   # Labor Day
    datetime(2025, 11, 27), # Thanksgiving
    datetime(2025, 12, 25), # Christmas
]

def get_daily_multiplier(current_date: datetime, location: str) -> dict:
    """Calculate daily multiplier based on seasonality, weekends, and holidays.
    
    Returns a dict with 'store' and 'fuel' multipliers.
    """
    # Day of year for seasonality (1-365)
    day_of_year = current_date.timetuple().tm_yday
    
    # Seasonality: Sine wave with peak in summer (day 180-200) and low in winter
    seasonality = 1.0 + 0.25 * math.sin((day_of_year - 80) * 2 * math.pi / 365)
    
    # Weekend multiplier (Saturday and Sunday)
    is_weekend = current_date.weekday() >= 5  # 5=Saturday, 6=Sunday
    weekend_multiplier = 1.15 if is_weekend else 1.0
    
    # Holiday multiplier
    is_holiday = current_date.date() in [h.date() for h in HOLIDAYS_2025]
    holiday_multiplier = 1.25 if is_holiday else 1.0
    
    # Combine multipliers
    combined = seasonality * weekend_multiplier * holiday_multiplier
    
    # Add some random variation (+/-5%)
    variation = random.uniform(0.95, 1.05)
    
    return {
        'store': combined * variation,
        'fuel': combined * variation
    }

def biased_monthly_target(location: str, low: float = 140_000.0, high: float = 300_000.0) -> float:
    """Return a biased monthly target using a triangular distribution.
    Mode per city (most likely value) is chosen to skew within [low, high]:
    - Houston: high-biased
    - Dallas: mid-high
    - Austin: mid
    - San Antonio: low-mid
    Defaults to mid if location is unrecognized.
    """
    # Scale the input bounds
    low = low * SCALING_FACTOR
    high = high * SCALING_FACTOR
    
    modes = {
        'Houston': 280_000.0 * SCALING_FACTOR,
        'Dallas': 240_000.0 * SCALING_FACTOR,
        'Austin': 200_000.0 * SCALING_FACTOR,
        'San Antonio': 170_000.0 * SCALING_FACTOR,
    }
    mode = modes.get(location, (low + high) / 2.0)
    mode = max(low, min(high, mode))
    return random.triangular(low, high, mode)

def generate_sample_data(num_days=365, start_date_str='2025-01-01', end_date_str='2025-12-31'):
    """Generate sample data with natural patterns using seasonality, holidays, and weekends.
    
    Args:
        num_days: Number of days to generate (default 365 for full year)
        start_date_str: Start date in format 'YYYY-MM-DD' (default '2025-01-01')
        end_date_str: End date in format 'YYYY-MM-DD' (default '2025-12-31')
    """

    session_start = datetime.now()

    try:
        conn = psycopg2.connect(**conn_params)
        cur = conn.cursor()

        # Determine date range
        if start_date_str and end_date_str:
            start_date = datetime.strptime(start_date_str, '%Y-%m-%d')
            end_date = datetime.strptime(end_date_str, '%Y-%m-%d')
            num_days = (end_date - start_date).days + 1
            print(f"Generating sample data from {start_date_str} to {end_date_str} ({num_days} days)...")
        else:
            start_date = datetime(2025, 1, 1)
            end_date = datetime(2025, 12, 31)
            num_days = 365
            print(f"Generating sample data for FY 2025 ({num_days} days)...")

        # Get station IDs
        cur.execute("SELECT station_id, location FROM analytics.stations")
        stations = cur.fetchall()

        fuel_sales_count = 0
        store_sales_count = 0

        for station_id, location in stations:
            print(f"Generating data for {location}...")
            
            # Get base daily averages for this location
            base_store = BASE_DAILY_AVERAGES.get(location, BASE_DAILY_AVERAGES['San Antonio'])['store'] * SCALING_FACTOR
            base_fuel = BASE_DAILY_AVERAGES.get(location, BASE_DAILY_AVERAGES['San Antonio'])['fuel'] * SCALING_FACTOR

            for day in range(num_days):
                current_date = start_date + timedelta(days=day)
                
                # Get daily multiplier based on seasonality, weekends, holidays
                multipliers = get_daily_multiplier(current_date, location)
                
                # Calculate target amounts for the day
                target_store_daily = base_store * multipliers['store']
                target_fuel_daily = base_fuel * multipliers['fuel']

                # Generate fuel sales (50-150 transactions per day per station)
                num_fuel_sales = random.randint(50, 150)
                
                # Calculate average transaction amount to hit daily target
                avg_fuel_transaction = target_fuel_daily / num_fuel_sales
                
                for _ in range(num_fuel_sales):
                    transaction_time = current_date + timedelta(
                        hours=random.randint(6, 22),
                        minutes=random.randint(0, 59)
                    )

                    fuel_type = random.choice(fuel_types)
                    
                    # Vary transaction amount around the average (+/-30%)
                    transaction_target = avg_fuel_transaction * random.uniform(0.7, 1.3)
                    
                    # Price variations
                    base_price = {'Regular': 3.29, 'Premium': 3.79, 'Diesel': 3.59}
                    price_variance = random.uniform(-0.10, 0.10)
                    price_per_gallon = round(base_price[fuel_type] + price_variance, 3)
                    
                    # Calculate gallons to match transaction target
                    gallons = round(transaction_target / price_per_gallon, 3)
                    gallons = max(5.0, min(25.0, gallons))  # 5-25 gallons

                    total_amount = round(gallons * price_per_gallon, 2)
                    payment_method = random.choice(payment_methods)

                    cur.execute(
                        """
                        INSERT INTO analytics.fuel_sales 
                        (station_id, transaction_date, fuel_type, gallons, 
                         price_per_gallon, total_amount, payment_method)
                        VALUES (%s, %s, %s, %s, %s, %s, %s)
                        """,
                        (station_id, transaction_time, fuel_type, gallons,
                         price_per_gallon, total_amount, payment_method),
                    )

                    fuel_sales_count += 1

                # Generate store sales (100-300 transactions per day per station)
                num_store_sales = random.randint(100, 300)
                
                # Calculate average transaction amount to hit daily target
                avg_store_transaction = target_store_daily / num_store_sales
                
                for _ in range(num_store_sales):
                    transaction_time = current_date + timedelta(
                        hours=random.randint(6, 23),
                        minutes=random.randint(0, 59)
                    )

                    category = random.choice(product_categories)
                    product_name = random.choice(products[category])
                    quantity = random.randint(1, 5)

                    # Price ranges by category (base)
                    price_ranges = {
                        'Snacks': (1.99, 5.99),
                        'Beverages': (1.49, 4.99),
                        'Tobacco': (7.99, 12.99),
                        'Automotive': (3.99, 15.99),
                        'Food': (2.99, 7.99),
                    }

                    # Calculate unit price to approximate target transaction amount
                    transaction_target = avg_store_transaction * random.uniform(0.7, 1.3)
                    target_unit_price = transaction_target / quantity
                    
                    # Keep within category price range
                    min_price, max_price = price_ranges[category]
                    unit_price = round(max(min_price, min(max_price, target_unit_price)), 2)
                    
                    total_amount = round(unit_price * quantity, 2)
                    payment_method = random.choice(payment_methods)

                    cur.execute(
                        """
                        INSERT INTO analytics.store_sales 
                        (station_id, transaction_date, product_category, product_name,
                         quantity, unit_price, total_amount, payment_method)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                        """,
                        (station_id, transaction_time, category, product_name,
                         quantity, unit_price, total_amount, payment_method),
                    )

                    store_sales_count += 1

        # Inventory data (not scaled)
        print("Generating inventory data...")
        for station_id, location in stations:
            for category, items in products.items():
                for product in items:
                    current_stock = random.randint(20, 200)
                    min_stock = random.randint(10, 30)
                    max_stock = random.randint(100, 300)
                    unit_cost = round(random.uniform(0.50, 8.00), 2)

                    cur.execute(
                        """
                        INSERT INTO analytics.inventory
                        (station_id, product_name, category, current_stock,
                         min_stock_level, max_stock_level, unit_cost, last_restocked)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                        """,
                        (station_id, product, category, current_stock,
                         min_stock, max_stock, unit_cost, datetime.now()),
                    )

        # Fuel inventory (not scaled)
        print("Generating fuel inventory data...")
        for station_id, location in stations:
            for fuel_type in fuel_types:
                tank_capacity = 12000.0  # gallons
                current_level = round(random.uniform(3000, 10000), 2)
                last_delivery = datetime.now() - timedelta(days=random.randint(1, 7))
                last_delivery_gallons = round(random.uniform(5000, 8000), 2)

                cur.execute(
                    """
                    INSERT INTO analytics.fuel_inventory
                    (station_id, fuel_type, tank_capacity, current_level,
                     last_delivery_date, last_delivery_gallons)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    """,
                    (station_id, fuel_type, tank_capacity, current_level,
                     last_delivery, last_delivery_gallons),
                )

        conn.commit()

        # Report results
        print("\n" + "=" * 70)
        print("Sample Data Generation Complete!")
        print("=" * 70)
        print(f"Date Range: {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}")
        print(f"Total Days: {num_days}")
        print(f"Fuel Sales Records: {fuel_sales_count:,}")
        print(f"Store Sales Records: {store_sales_count:,}")
        print("\nStation Summary:")
        print("-" * 70)
        
        session_window_clause = "created_at >= %s AND transaction_date >= %s"
        session_window_params = (session_start, start_date)
        
        for station_id, location in stations:
            cur.execute(
                f"""
                SELECT COALESCE(SUM(total_amount), 0) FROM analytics.store_sales
                WHERE station_id = %s AND {session_window_clause}
                """,
                (station_id, *session_window_params),
            )
            ssum = cur.fetchone()[0] or 0
            cur.execute(
                f"""
                SELECT COALESCE(SUM(total_amount), 0) FROM analytics.fuel_sales
                WHERE station_id = %s AND {session_window_clause}
                """,
                (station_id, *session_window_params),
            )
            fsum = cur.fetchone()[0] or 0
            total = ssum + fsum
            store_pct = (ssum / total * 100) if total > 0 else 0
            fuel_pct = (fsum / total * 100) if total > 0 else 0
            daily_avg = total / num_days if num_days > 0 else 0
            
            print(f"{location:15} | Total: ${total:>12,.2f} | Daily Avg: ${daily_avg:>10,.2f}")
            print(f"{'':15} | Store: ${ssum:>12,.2f} ({store_pct:>5.1f}%) | Fuel: ${fsum:>12,.2f} ({fuel_pct:>5.1f}%)")
            print("-" * 70)
        print("=" * 70)

    except psycopg2.Error as db_err:
        print(f"Database error: {db_err}")
        try:
            conn.rollback()
        except Exception:  # pylint: disable=broad-except
            pass
    except Exception as e:  # pylint: disable=broad-except
        print(f"Error: {e}")
        try:
            conn.rollback()
        except Exception:  # pylint: disable=broad-except
            pass
    finally:
        try:
            cur.close()
        except Exception:  # pylint: disable=broad-except
            pass
        try:
            conn.close()
        except Exception:  # pylint: disable=broad-except
            pass

if __name__ == "__main__":
    print("Cagridge Data Lakehouse - Sample Data Generator")
    print("="*70)
    print("Default: FY 2025 (Jan 1 - Dec 31, 2025)")
    print("="*70)
    
    # Ask if user wants to use defaults or custom dates
    use_default = input("\nGenerate full year 2025 data? [Y/n]: ").strip().lower()
    
    if use_default in ['', 'y', 'yes']:
        generate_sample_data(start_date_str='2025-01-01', end_date_str='2025-12-31')
    else:
        input_start_date = input("Enter start date (YYYY-MM-DD): ").strip()
        input_end_date = input("Enter end date (YYYY-MM-DD): ").strip()
        if input_start_date and input_end_date:
            generate_sample_data(start_date_str=input_start_date, end_date_str=input_end_date)
        else:
            print("Invalid date range. Using default full year 2025.")
            generate_sample_data(start_date_str='2025-01-01', end_date_str='2025-12-31')
