const services = {
  dashboard: { ip: 'localhost', port: 30000, endpoint: '/', name: 'Dashboard' },
  postgres: { ip: 'localhost', port: 30001, endpoint: null, name: 'PostgreSQL' },
  minio: { ip: 'localhost', port: 30002, endpoint: '/minio/health/live', name: 'MinIO' },
  nessie: { ip: 'localhost', port: 30003, endpoint: '/q/health/live', name: 'Nessie' },
  trino: { ip: 'localhost', port: 30004, endpoint: '/v1/info', name: 'Trino' },
  dbt: { ip: 'localhost', port: 30005, endpoint: null, name: 'dbt' }, // dbt doesn't have a web endpoint
  airflow: { ip: 'localhost', port: 30006, endpoint: '/health', name: 'Airflow' },
  prometheus: { ip: 'localhost', port: 30007, endpoint: '/-/healthy', name: 'Prometheus' },
  grafana: { ip: 'localhost', port: 30008, endpoint: '/api/health', name: 'Grafana' }
};

// Station info
const stationData = {
  'Houston': {
    name: 'Cagridge Houston Main',
    address: '1234 Main St, Houston, TX 77002',
    phone: '(713) 555-1234',
    hours: '24 Hours'
  },
  'Dallas': {
    name: 'Cagridge Dallas Central',
    address: '5678 Central Ave, Dallas, TX 75201',
    phone: '(214) 555-5678',
    hours: '24 Hours'
  },
  'Austin': {
    name: 'Cagridge Austin Downtown',
    address: '9012 Congress Ave, Austin, TX 78701',
    phone: '(512) 555-9012',
    hours: 'Mon-Sun: 6:00 AM - 11:00 PM'
  },
  'San Antonio': {
    name: 'Cagridge San Antonio Plaza',
    address: '3456 Commerce St, San Antonio, TX 78205',
    phone: '(210) 555-3456',
    hours: 'Mon-Sun: 6:00 AM - 11:00 PM'
  }
};

// --- MODAL FUNCTIONS ---
const modal = document.getElementById('info-modal');
const modalTitle = document.getElementById('modal-title');
const modalContent = document.getElementById('modal-content');

// ShowModal function
function showModal(title, content) {
  if (modal && modalTitle && modalContent) {
    modalTitle.textContent = title;
    modalContent.textContent = content;
    modal.classList.remove('hidden');
  }
}

// hideModal function called by onclick in index.html
function hideModal() {
  if (modal) {
    modal.classList.add('hidden');
  }
}
// --- END OF MODAL FUNCTIONS ---

function openService(url) {
  window.open(url, '_blank');
}

function showPostgresInfo() {
  const title = "PostgreSQL Connection Info";
  const content = `Service is running and accessible to other pods via:
Host: postgres-service`;
  showModal(title, content);
}

// Update the date for the KPI section
function updateKpiDate() {
  const kpiDateDisplay = document.getElementById('kpi-date-display');
  if (!kpiDateDisplay) return;

  // Get today's date from the user's browser
  const today = new Date();

  // Calculate yesterday's date
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);

  // Format as "Month Day, Year" (e.g., November 13, 2025)
  const options = { month: 'long', day: 'numeric', year: 'numeric' };
  const formattedDate = yesterday.toLocaleDateString('en-US', options);

  // Update the HTML
  kpiDateDisplay.textContent = `(As of ${formattedDate})`;
}


async function checkServiceHealth(serviceName, config) {
  const card = document.querySelector(`[data-service="${serviceName}"]`);
  if (!card) return false; // Exit if card not found
  
  const statusIndicator = card.querySelector('.status-indicator');
  const statusText = card.querySelector('.service-status');

  if (serviceName === 'postgres' || serviceName === 'dbt') {
      if(statusIndicator) statusIndicator.className = 'status-indicator status-online';
      if(statusText) statusText.textContent = 'Ready';
      return true;
  }

  try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 5000);

      const response = await fetch(`http://${config.ip}:${config.port}${config.endpoint || '/'}`, {
      method: 'GET',
      mode: 'no-cors', // 'no-cors' is needed for cross-origin checks, but limits response reading
      signal: controller.signal
      });

      clearTimeout(timeoutId);

      if(statusIndicator) statusIndicator.className = 'status-indicator status-online';
      if(statusText) statusText.textContent = 'Online';
      return true;
  } catch (error) {
      // To catch network errors (service down) or timeouts
      if (error.name === 'AbortError') {
      if(statusIndicator) statusIndicator.className = 'status-indicator status-offline';
      if(statusText) statusText.textContent = 'Timeout';
      } else {
      if(statusIndicator) statusIndicator.className = 'status-indicator status-offline';
      if(statusText) statusText.textContent = 'Offline';
      }
      return false;
  }
}

async function checkAllServices() {
  let onlineCount = 0;
  const serviceKeys = Object.keys(services);

  for (const name of serviceKeys) {
      const config = services[name];
      const isOnline = await checkServiceHealth(name, config);
      if (isOnline) onlineCount++;
  }

  const serviceCountEl = document.getElementById('serviceCount');
  if(serviceCountEl) {
      serviceCountEl.textContent = `${onlineCount} / ${serviceKeys.length} Services Online`;
  }
}

// Check service health on page load
window.addEventListener('load', () => {
  checkAllServices();
  updateKpiDate();
  // Refresh every 30 seconds
  setInterval(checkAllServices, 30000);
});

// Theme toggle function
function toggleTheme() {
  const html = document.documentElement;
  const currentTheme = html.classList.contains('dark') ? 'dark' : 'light';
  const newTheme = currentTheme === 'dark' ? 'light' : 'dark';

  if (newTheme === 'dark') {
    html.classList.add('dark');
  } else {
    html.classList.remove('dark');
  }

  // Save preference
  localStorage.setItem('theme', newTheme);
}

// Load theme preference
function loadThemePreference() {
  const savedTheme = localStorage.getItem('theme');
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

  if (savedTheme === 'light') {
    document.documentElement.classList.remove('dark');
  } else if (savedTheme === 'dark' || (!savedTheme && prefersDark)) {
    document.documentElement.classList.add('dark');
  }
}

// Load theme before page renders
loadThemePreference();

// Auto-refresh page every 5 minutes
setTimeout(() => location.reload(), 300000);