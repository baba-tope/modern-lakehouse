import os
import logging
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import psycopg2
import psycopg2.extras
from pydantic import BaseModel
from typing import Optional, Dict

logger = logging.getLogger("dashboard-api")

# Pydantic Models for Response Validation
class Kpis(BaseModel):
    total_revenue: Optional[float] = 0.0
    total_gallons: Optional[float] = 0.0
    store_revenue: Optional[float] = 0.0
    total_transactions: Optional[int] = 0

class DashboardData(BaseModel):
    kpis: Kpis
    ops: Dict[str, str]

# --- FastAPI App Initialization ---
app = FastAPI(
    title="Cagridge Dashboard API",
    description="Provides BI and Ops data for the main dashboard.",
    version="1.0.0"
)

# CORS: the dashboard is a static site served from a different origin, so
# cross-origin GETs are allowed. Origins are configurable via
# DASHBOARD_ALLOWED_ORIGINS (comma-separated); the default "*" is safe here
# because this is public, read-only data and credentials are disabled --
# "*" together with allow_credentials=True is the invalid/insecure combination.
_origins = [o.strip() for o in os.getenv("DASHBOARD_ALLOWED_ORIGINS", "*").split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)

# Database Connection
DB_HOST = os.getenv('DB_HOST', 'postgres-service')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('POSTGRES_DB')
DB_USER = os.getenv('POSTGRES_USER')
DB_PASS = os.getenv('POSTGRES_PASSWORD')

def get_db_connection():
    """Establishes a connection to the PostgreSQL database."""
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASS
        )
        return conn
    except Exception as e:
        logger.error("Error connecting to database: %s", e)
        return None

# API Endpoints
@app.get("/api/dashboard-data", response_model=DashboardData)
def get_dashboard_data():
    """
    Main API endpoint to fetch all BI and Ops data.
    Fetches the most recent date's data from the data mart.
    """
    conn = get_db_connection()
    if not conn:
        raise HTTPException(status_code=503, detail="Database connection failed")

    try:
        with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            # Key Business Metrics (KPIs) - Get most recent date available
            # Data is generated for FY 2025 with natural patterns (seasonality, holidays, weekends)
            cur.execute(
                """
                SELECT
                    SUM(total_revenue) AS total_revenue,
                    SUM(total_gallons) AS total_gallons,
                    SUM(store_revenue) AS store_revenue,
                    SUM(total_transactions) AS total_transactions
                FROM mart.fct_daily_sales
                WHERE sale_date = (
                    SELECT MAX(sale_date) FROM mart.fct_daily_sales
                )
                """
            )
            kpis_data = cur.fetchone()
            kpis = Kpis(**kpis_data) if kpis_data else Kpis()

            # Operational Status (Ops)
            cur.execute("SELECT metric_name, metric_value FROM analytics.dashboard_metrics")
            ops_rows = cur.fetchall()
            ops = {row['metric_name']: row['metric_value'] for row in ops_rows}

            # Combine results
            response_data = DashboardData(kpis=kpis, ops=ops)
            
            return response_data

    except HTTPException:
        raise
    except Exception as e:
        logger.error("Error executing query: %s", e)
        raise HTTPException(status_code=500, detail="Failed to retrieve data")
    finally:
        if conn:
            conn.close()

# Run the application
if __name__ == '__main__':
    uvicorn.run(app, host='0.0.0.0', port=8081)