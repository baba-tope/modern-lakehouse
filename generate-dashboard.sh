#!/usr/bin/env bash
set -euo pipefail

# Generate dashboard HTML with IP addresses from .env

project_root="$(cd "$(dirname "$0")" && pwd)"
cd "$project_root"

if [[ ! -f .env ]]; then
  echo "[✗] .env file not found" >&2
  exit 1
fi

# Load .env
set -a
source ./.env
set +a

echo "[•] Generating dashboard with localhost URLs..."

# Use localhost with NodePorts for reliable Windows access
for file in dashboard/index.html dashboard/scripts.js; do
  if [[ -f "$file" ]]; then
    sed -e "s|http://[0-9.]*:30000|http://localhost:30000|g" \
        -e "s|http://[0-9.]*:30001|http://localhost:30001|g" \
        -e "s|http://[0-9.]*:30002|http://localhost:30002|g" \
        -e "s|http://[0-9.]*:30003|http://localhost:30003|g" \
        -e "s|http://[0-9.]*:30004|http://localhost:30004|g" \
        -e "s|http://[0-9.]*:30005|http://localhost:30005|g" \
        -e "s|http://[0-9.]*:30006|http://localhost:30006|g" \
        -e "s|http://[0-9.]*:30007|http://localhost:30007|g" \
        -e "s|http://[0-9.]*:30008|http://localhost:30008|g" \
        -e "s|http://[0-9.]*:30009|http://localhost:30009|g" \
        "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
  fi
done

echo "[✓] Dashboard generated successfully"
echo "    Using localhost:3000X URLs for all services"
