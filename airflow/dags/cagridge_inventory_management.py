"""
Cagridge Data Lakehouse - Inventory Management DAG
Monitors and manages inventory across all stations
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
import logging

default_args = {
    'owner': 'cagridge',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 1),
    'email': ['inventory@cagridge.com'],
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'cagridge_inventory_management',
    default_args=default_args,
    description='Inventory monitoring and alerts for all stations',
    schedule_interval='0 */4 * * *',  # Run every 4 hours
    catchup=False,
    tags=['cagridge', 'inventory', 'monitoring'],
)

def check_fuel_levels(**context):
    """Check fuel levels and alert if below threshold"""
    logging.info("Checking fuel inventory levels...")
    
    pg_hook = PostgresHook(postgres_conn_id='postgres_default')
    sql = """
        SELECT 
            s.station_name,
            s.location,
            fi.fuel_type,
            fi.current_level,
            fi.tank_capacity,
            (fi.current_level / fi.tank_capacity * 100) as percentage_full
        FROM analytics.fuel_inventory fi
        JOIN analytics.stations s ON fi.station_id = s.station_id
        WHERE (fi.current_level / fi.tank_capacity) < 0.25
        ORDER BY percentage_full ASC
    """
    
    low_fuel_tanks = pg_hook.get_records(sql)
    
    if low_fuel_tanks:
        logging.warning(f"Found {len(low_fuel_tanks)} tanks below 25% capacity")
        for tank in low_fuel_tanks:
            station, location, fuel_type, level, capacity, pct = tank
            logging.warning(f"ALERT: {station} ({location}) - {fuel_type}: {pct:.1f}% full")
        
        context['ti'].xcom_push(key='low_fuel_alerts', value=len(low_fuel_tanks))
    else:
        logging.info("All fuel tanks above 25% capacity")
        context['ti'].xcom_push(key='low_fuel_alerts', value=0)
    
    return len(low_fuel_tanks)

def check_store_inventory(**context):
    """Check store inventory and flag items below minimum"""
    logging.info("Checking store inventory levels...")
    
    pg_hook = PostgresHook(postgres_conn_id='postgres_default')
    sql = """
        SELECT 
            s.station_name,
            s.location,
            i.product_name,
            i.category,
            i.current_stock,
            i.min_stock_level
        FROM analytics.inventory i
        JOIN analytics.stations s ON i.station_id = s.station_id
        WHERE i.current_stock < i.min_stock_level
        ORDER BY s.location, i.category
    """
    
    low_stock_items = pg_hook.get_records(sql)
    
    if low_stock_items:
        logging.warning(f"Found {len(low_stock_items)} items below minimum stock")
        
        # Group by station
        station_alerts = {}
        for item in low_stock_items:
            station, location, product, category, current, minimum = item
            key = f"{station} ({location})"
            if key not in station_alerts:
                station_alerts[key] = []
            station_alerts[key].append({
                'product': product,
                'category': category,
                'current': current,
                'minimum': minimum
            })
        
        for station, items in station_alerts.items():
            logging.warning(f"ALERT: {station} has {len(items)} items below minimum")
            for item in items[:5]:  # Show first 5
                logging.warning(f"  - {item['product']} ({item['category']}): {item['current']}/{item['minimum']}")
        
        context['ti'].xcom_push(key='low_stock_alerts', value=len(low_stock_items))
    else:
        logging.info("All items above minimum stock levels")
        context['ti'].xcom_push(key='low_stock_alerts', value=0)
    
    return len(low_stock_items)

def generate_reorder_recommendations(**context):
    """Generate automatic reorder recommendations"""
    logging.info("Generating reorder recommendations...")
    
    fuel_alerts = context['ti'].xcom_pull(key='low_fuel_alerts')
    stock_alerts = context['ti'].xcom_pull(key='low_stock_alerts')
    
    total_alerts = fuel_alerts + stock_alerts
    
    if total_alerts > 0:
        logging.info(f"Total alerts: {total_alerts} (Fuel: {fuel_alerts}, Stock: {stock_alerts})")
        logging.info("Recommendations:")
        logging.info("1. Review low fuel tanks and schedule deliveries")
        logging.info("2. Generate purchase orders for low stock items")
        logging.info("3. Notify station managers")
    else:
        logging.info("No reorder recommendations needed")
    
    return {
        'fuel_alerts': fuel_alerts,
        'stock_alerts': stock_alerts,
        'total_alerts': total_alerts
    }

def update_inventory_metrics(**context):
    """Update inventory performance metrics"""
    logging.info("Updating inventory metrics...")
    
    pg_hook = PostgresHook(postgres_conn_id='postgres_default')
    
    # Calculate inventory turnover
    sql = """
        SELECT 
            s.location,
            COUNT(DISTINCT i.product_name) as total_products,
            AVG(i.current_stock) as avg_stock_level
        FROM analytics.inventory i
        JOIN analytics.stations s ON i.station_id = s.station_id
        GROUP BY s.location
    """
    
    metrics = pg_hook.get_records(sql)
    
    for metric in metrics:
        location, product_count, avg_stock = metric
        logging.info(f"{location}: {product_count} products, avg stock: {avg_stock:.1f}")
    
    return len(metrics)

# Write inventory alerts to the dashboard table
def update_dashboard_inventory_metrics(**context):
    """Saves the inventory alert counts to the dashboard metrics table."""
    logging.info("Updating dashboard inventory metrics...")
    pg_hook = PostgresHook(postgres_conn_id='postgres_default')
    
    ti = context['ti']
    fuel_alerts = ti.xcom_pull(key='low_fuel_alerts', task_ids='check_fuel_levels')
    stock_alerts = ti.xcom_pull(key='low_stock_alerts', task_ids='check_store_inventory')
    
    sql = """
        INSERT INTO analytics.dashboard_metrics (metric_name, metric_value, updated_at)
        VALUES
            ('inv_last_run', 'Success', NOW()),
            ('inv_fuel_alerts', %s, NOW()),
            ('inv_stock_alerts', %s, NOW())
        ON CONFLICT (metric_name) DO UPDATE
        SET metric_value = EXCLUDED.metric_value, updated_at = EXCLUDED.updated_at;
    """
    pg_hook.run(sql, parameters=(fuel_alerts, stock_alerts))
    logging.info(f"Dashboard inventory metrics updated: fuel_alerts={fuel_alerts}, stock_alerts={stock_alerts}")

# Define tasks
check_fuel_task = PythonOperator(
    task_id='check_fuel_levels',
    python_callable=check_fuel_levels,
    dag=dag,
)

check_inventory_task = PythonOperator(
    task_id='check_store_inventory',
    python_callable=check_store_inventory,
    dag=dag,
)

reorder_task = PythonOperator(
    task_id='generate_reorder_recommendations',
    python_callable=generate_reorder_recommendations,
    dag=dag,
)

metrics_task = PythonOperator(
    task_id='update_inventory_metrics',
    python_callable=update_inventory_metrics,
    dag=dag,
)

update_dashboard_inv_task = PythonOperator(
    task_id='update_dashboard_inventory_metrics',
    python_callable=update_dashboard_inventory_metrics,
    dag=dag,
)

# Define task dependencies
[check_fuel_task, check_inventory_task] >> reorder_task >> metrics_task >> update_dashboard_inv_task
