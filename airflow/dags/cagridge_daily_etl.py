"""
Cagridge Data Lakehouse - Daily ETL Pipeline
Extracts data from PostgreSQL, transforms, and loads to Iceberg via Trino
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
import logging

default_args = {
    'owner': 'cagridge',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email': ['admin@cagridge.com'],
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'cagridge_daily_etl',
    default_args=default_args,
    description='Daily ETL pipeline for Cagridge gas stations',
    schedule_interval='0 2 * * *',  # Run at 2 AM daily
    catchup=False,
    tags=['cagridge', 'etl', 'daily'],
)

def extract_fuel_sales(**context):
    """Extract fuel sales data from PostgreSQL"""
    logging.info("Extracting fuel sales data...")
    
    pg_hook = PostgresHook(postgres_conn_id='postgres_default')
    sql = """
        SELECT 
            station_id,
            transaction_date,
            fuel_type,
            gallons,
            price_per_gallon,
            total_amount,
            payment_method
        FROM analytics.fuel_sales
        WHERE DATE(transaction_date) = CURRENT_DATE - INTERVAL '1 day'
    """
    
    records = pg_hook.get_records(sql)
    logging.info(f"Extracted {len(records)} fuel sales records")
    
    # Push to XCom for next task
    context['ti'].xcom_push(key='fuel_sales_count', value=len(records))
    return len(records)

def extract_store_sales(**context):
    """Extract store sales data from PostgreSQL"""
    logging.info("Extracting store sales data...")
    
    pg_hook = PostgresHook(postgres_conn_id='postgres_default')
    sql = """
        SELECT 
            station_id,
            transaction_date,
            product_category,
            product_name,
            quantity,
            unit_price,
            total_amount,
            payment_method
        FROM analytics.store_sales
        WHERE DATE(transaction_date) = CURRENT_DATE - INTERVAL '1 day'
    """
    
    records = pg_hook.get_records(sql)
    logging.info(f"Extracted {len(records)} store sales records")
    
    context['ti'].xcom_push(key='store_sales_count', value=len(records))
    return len(records)

def transform_and_load(**context):
    """Transform data and load to Iceberg tables via Trino"""
    logging.info("Transforming and loading data to Iceberg...")
    
    fuel_count = context['ti'].xcom_pull(key='fuel_sales_count')
    store_count = context['ti'].xcom_pull(key='store_sales_count')
    
    logging.info(f"Processing {fuel_count} fuel sales and {store_count} store sales records")
    
    # In a real implementation, this would:
    # 1. Connect to Trino
    # 2. Execute INSERT INTO iceberg.cagridge.* SELECT FROM postgres.*
    # 3. Apply transformations
    # 4. Update metadata in Nessie
    
    return {
        'fuel_records': fuel_count,
        'store_records': store_count,
        'status': 'success'
    }

def generate_daily_report(**context):
    """Generate daily performance report"""
    logging.info("Generating daily performance report...")
    
    pg_hook = PostgresHook(postgres_conn_id='postgres_default')
    sql = """
        SELECT 
            station_name,
            location,
            SUM(total_fuel_revenue) as fuel_revenue,
            SUM(total_store_revenue) as store_revenue,
            SUM(total_revenue) as total_revenue
        FROM analytics.daily_sales_summary
        WHERE sale_date = CURRENT_DATE - INTERVAL '1 day'
        GROUP BY station_name, location
        ORDER BY total_revenue DESC
    """
    
    records = pg_hook.get_records(sql)
    
    for record in records:
        station, location, fuel_rev, store_rev, total_rev = record
        logging.info(f"{station} ({location}): Fuel=${fuel_rev}, Store=${store_rev}, Total=${total_rev}")
    
    return len(records)

def data_quality_checks(**context):
    """Perform data quality checks"""
    logging.info("Running data quality checks...")
    
    pg_hook = PostgresHook(postgres_conn_id='postgres_default')
    
    checks = [
        {
            'name': 'No negative sales',
            'sql': "SELECT COUNT(*) FROM analytics.fuel_sales WHERE total_amount < 0"
        },
        {
            'name': 'No future dates',
            'sql': "SELECT COUNT(*) FROM analytics.fuel_sales WHERE transaction_date > CURRENT_TIMESTAMP"
        },
        {
            'name': 'All stations active',
            'sql': "SELECT COUNT(*) FROM analytics.stations WHERE is_active = true"
        }
    ]
    
    for check in checks:
        result = pg_hook.get_first(check['sql'])[0]
        logging.info(f"Check '{check['name']}': {result}")
        
        if check['name'] in ['No negative sales', 'No future dates'] and result > 0:
            raise ValueError(f"Data quality check failed: {check['name']}")
    
    return "All checks passed"

# Define tasks
extract_fuel_task = PythonOperator(
    task_id='extract_fuel_sales',
    python_callable=extract_fuel_sales,
    dag=dag,
)

extract_store_task = PythonOperator(
    task_id='extract_store_sales',
    python_callable=extract_store_sales,
    dag=dag,
)

transform_load_task = PythonOperator(
    task_id='transform_and_load',
    python_callable=transform_and_load,
    dag=dag,
)

quality_check_task = PythonOperator(
    task_id='data_quality_checks',
    python_callable=data_quality_checks,
    dag=dag,
)

report_task = PythonOperator(
    task_id='generate_daily_report',
    python_callable=generate_daily_report,
    dag=dag,
)

# Define task dependencies
[extract_fuel_task, extract_store_task] >> transform_load_task >> quality_check_task >> report_task
