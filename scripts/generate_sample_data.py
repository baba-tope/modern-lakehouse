# Sample Data Generator for Cagridge Gas Stations
# Run this after PostgreSQL is initialized

import os
import random
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
# Use localhost for Windows host access via NodePort
conn_params = {
    'host': 'localhost',  # Access via NodePort on Windows host
    'port': int(os.getenv('POSTGRES_PORT', '30001')),
    'database': os.getenv('POSTGRES_DB'),
    'user': os.getenv('POSTGRES_USER'),
    'password': os.getenv('POSTGRES_PASSWORD')
}

# Sample data
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


def biased_monthly_target(location: str, low: float = 140_000.0, high: float = 300_000.0) -> float:
    """Return a biased monthly target using a triangular distribution.
    Mode per city (most likely value) is chosen to skew within [low, high]:
    - Houston: high-biased
    - Dallas: mid-high
    - Austin: mid
    - San Antonio: low-mid
    Defaults to mid if location is unrecognized.
    """
    modes = {
        'Houston': 280_000.0,
        'Dallas': 240_000.0,
        'Austin': 200_000.0,
        'San Antonio': 170_000.0,
    }
    mode = modes.get(location, (low + high) / 2.0)
    # Ensure mode is within [low, high]
    mode = max(low, min(high, mode))
    return random.triangular(low, high, mode)

def generate_sample_data(num_days=30, start_date_str=None, end_date_str=None):
    """Generate sample data for the last N days or between specific dates and enforce per-station period totals:
    total in [140k, 300k], with 65% store, 35% fuel.
    
    Args:
        num_days: Number of days to generate (used if start_date_str and end_date_str not provided)
        start_date_str: Start date in format 'YYYY-MM-DD' (optional)
        end_date_str: End date in format 'YYYY-MM-DD' (optional)
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
            start_date = datetime.now() - timedelta(days=num_days)
            print(f"Generating sample data for the last {num_days} days...")

        # Get station IDs
        cur.execute("SELECT station_id, location FROM analytics.stations")
        stations = cur.fetchall()

        fuel_sales_count = 0
        store_sales_count = 0

        for station_id, location in stations:
            print(f"Generating data for {location}...")

            for day in range(num_days):
                current_date = start_date + timedelta(days=day)

                # Generate fuel sales (50-150 transactions per day per station)
                num_fuel_sales = random.randint(50, 150)
                for _ in range(num_fuel_sales):
                    transaction_time = current_date + timedelta(
                        hours=random.randint(6, 22),
                        minutes=random.randint(0, 59)
                    )

                    fuel_type = random.choice(fuel_types)
                    gallons = round(random.uniform(5, 20), 3)

                    # Price variations
                    base_price = {'Regular': 3.29, 'Premium': 3.79, 'Diesel': 3.59}
                    price_variance = random.uniform(-0.10, 0.10)
                    price_per_gallon = round(base_price[fuel_type] + price_variance, 3)

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
                for _ in range(num_store_sales):
                    transaction_time = current_date + timedelta(
                        hours=random.randint(6, 23),
                        minutes=random.randint(0, 59)
                    )

                    category = random.choice(product_categories)
                    product_name = random.choice(products[category])
                    quantity = random.randint(1, 5)

                    # Price ranges by category
                    price_ranges = {
                        'Snacks': (1.99, 5.99),
                        'Beverages': (1.49, 4.99),
                        'Tobacco': (7.99, 12.99),
                        'Automotive': (3.99, 15.99),
                        'Food': (2.99, 7.99),
                    }

                    unit_price = round(random.uniform(*price_ranges[category]), 2)
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

        # Phase 2: scale sales to match monthly targets per station (65% store / 35% fuel)
        print("Applying monthly total targets per station (65% store / 35% fuel)...")
        session_window_clause = "created_at >= %s AND transaction_date >= %s"
        session_window_params = (session_start, start_date)

        for station_id, location in stations:
            # Current sums from this run only
            cur.execute(
                f"""
                SELECT COALESCE(SUM(total_amount), 0)
                FROM analytics.store_sales
                WHERE station_id = %s AND {session_window_clause}
                """,
                (station_id, *session_window_params),
            )
            store_sum = float(cur.fetchone()[0] or 0)

            cur.execute(
                f"""
                SELECT COALESCE(SUM(total_amount), 0)
                FROM analytics.fuel_sales
                WHERE station_id = %s AND {session_window_clause}
                """,
                (station_id, *session_window_params),
            )
            fuel_sum = float(cur.fetchone()[0] or 0)

            # Choose target monthly total in [140k, 300k], biased by city
            target_total = biased_monthly_target(location, 140_000.0, 300_000.0)
            target_store = 0.65 * target_total
            target_fuel = 0.35 * target_total

            # Compute scale factors (avoid divide by zero)
            scale_store = (target_store / store_sum) if store_sum > 0 else 1.0
            scale_fuel = (target_fuel / fuel_sum) if fuel_sum > 0 else 1.0

            # Update store sales: scale unit_price and total_amount
            cur.execute(
                f"""
                UPDATE analytics.store_sales
                SET unit_price = ROUND(unit_price * CAST(%s AS numeric), 2),
                    total_amount = ROUND(total_amount * CAST(%s AS numeric), 2)
                WHERE station_id = %s AND {session_window_clause}
                """,
                (scale_store, scale_store, station_id, *session_window_params),
            )

            # Update fuel sales: scale price_per_gallon and total_amount
            cur.execute(
                f"""
                UPDATE analytics.fuel_sales
                SET price_per_gallon = ROUND(price_per_gallon * CAST(%s AS numeric), 3),
                    total_amount = ROUND(total_amount * CAST(%s AS numeric), 2)
                WHERE station_id = %s AND {session_window_clause}
                """,
                (scale_fuel, scale_fuel, station_id, *session_window_params),
            )

        conn.commit()

        # Report results
        print("\n" + "=" * 50)
        print("Sample Data Generation Complete!")
        print("=" * 50)
        print(f"Fuel Sales Records: {fuel_sales_count}")
        print(f"Store Sales Records: {store_sales_count}")
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
            print(f"{location}: store=${ssum:,.2f} (≈65%), fuel=${fsum:,.2f} (≈35%), total=${total:,.2f}")
        print("=" * 50)

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
    print("="*50)
    
    # Ask for date range or number of days
    generation_mode = input("Generate by (1) date range or (2) number of days? [1/2] (default 2): ").strip()
    
    if generation_mode == "1":
        input_start_date = input("Enter start date (YYYY-MM-DD): ").strip()
        input_end_date = input("Enter end date (YYYY-MM-DD): ").strip()
        if input_start_date and input_end_date:
            generate_sample_data(start_date_str=input_start_date, end_date_str=input_end_date)
        else:
            print("Invalid date range. Using default 30 days.")
            generate_sample_data(30)
    else:
        days_str = input("Enter number of days to generate (default 30): ").strip()
        days_val = int(days_str) if days_str else 30
        generate_sample_data(days_val)
