//  Dashboard Data Collector - Fetches BI and Ops data from the backend API
//  Data covers FY 2025 with natural patterns:
//  - Seasonality (sine wave, peaks in summer)
//  - Holiday multipliers (1.25x on US holidays)
//  - Weekend multipliers (1.15x on Sat/Sun)
//  - Base daily averages vary by location (Houston highest, San Antonio lowest)

// API endpoint
const API_URL = 'http://localhost:30010/api/dashboard-data';

// Format numbers, e.g., 1234567.89 -> "1,234,568" or "1.23M"
function formatNumber(num) {
    if (num === null || num === undefined) return 'N/A';
    // Format large numbers (millions)
    if (Math.abs(num) >= 1000000) {
        return (num / 1000000).toFixed(2) + 'M';
    }
    // Format numbers with commas
    return Math.round(num).toLocaleString('en-US');
}

// Format currency, e.g., 1234567.89 -> "$1.23M"
function formatCurrency(num) {
    if (num === null || num === undefined) return '$0.00';
    
    // Format large currency (millions)
    if (Math.abs(num) >= 1000000) {
        return '$' + (num / 1000000).toFixed(2) + 'M';
    }
    // Format standard currency
    return '$' + num.toLocaleString('en-US', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    });
}

// Update text content of an element
function updateText(elementId, text, defaultText = 'N/A') {
    const el = document.getElementById(elementId);
    if (el) {
        el.textContent = text || defaultText;
    }
}

// Update status (indicator and text)
function updateStatus(elementId, text, isSuccess) {
    const el = document.getElementById(elementId);
    if (el) {
        el.textContent = text;
        el.className = isSuccess ? 'font-semibold text-green-500' : 'font-semibold text-red-500';
    }
    const indicator = document.getElementById(elementId + '-indicator');
    if (indicator) {
        indicator.className = isSuccess ? 'status-indicator status-online' : 'status-indicator status-offline';
    }
}

// Fetches data from the API and updates the dashboard.
async function fetchDashboardData() {
    try {
        const response = await fetch(API_URL);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();

        // Key Business Metrics (KPIs)
        const kpis = data.kpis;
        updateText('kpi-total-revenue', formatCurrency(kpis.total_revenue));
        updateText('kpi-fuel-gallons', formatNumber(kpis.total_gallons));
        updateText('kpi-store-revenue', formatCurrency(kpis.store_revenue));
        updateText('kpi-total-transactions', formatNumber(kpis.total_transactions));

        // Operational & Data Status
        const ops = data.ops;
        
        // ETL Pipeline
        const isEtlSuccess = ops.etl_last_run === 'Success';
        updateStatus('etl-last-run', ops.etl_last_run, isEtlSuccess);
        updateText('etl-fuel-count', formatNumber(ops.etl_fuel_count));
        updateText('etl-store-count', formatNumber(ops.etl_store_count));
        updateText('etl-next-run', ops.etl_next_run || 'Not Scheduled');

        // Inventory Alerts
        const invAlerts = parseInt(ops.inv_fuel_alerts, 10) + parseInt(ops.inv_stock_alerts, 10);
        const isInvSuccess = invAlerts === 0;
        updateStatus('inv-last-run', ops.inv_last_run, ops.inv_last_run === 'Success');
        updateText('inv-fuel-alerts', ops.inv_fuel_alerts);
        updateText('inv-stock-alerts', ops.inv_stock_alerts);
        
        // Change border color on alert
        const invCard = document.getElementById('inv-card');
        if (invCard) {
            invCard.className = isInvSuccess ? 'card p-6' : 'card p-6 border-amber-500';
        }

        // dbt Status
        const isDbtSuccess = ops.dbt_last_run === 'Success';
        updateStatus('dbt-last-run', ops.dbt_last_run, isDbtSuccess);
        updateText('dbt-staging-models', formatNumber(ops.dbt_staging_models));
        updateText('dbt-mart-models', formatNumber(ops.dbt_mart_models));
        updateText('dbt-tests', formatNumber(ops.dbt_tests));

    } catch (error) {
        console.error('Error fetching dashboard data:', error);
    }
}

// Run on page load, and then refresh every 60 seconds
window.addEventListener('load', () => {
    fetchDashboardData();
    setInterval(fetchDashboardData, 60000); // Refresh every 60 seconds
});