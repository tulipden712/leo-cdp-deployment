#!/usr/bin/env bash
# ----------------------------------------------------------
# 🚀 LEO CDP – Developer Auto-Start Script (Single Server)
# ----------------------------------------------------------
# Runs all core CDP services (Admin, Observer, Scheduler, Data Jobs)
# in background mode, with per-service logs for development.
# ----------------------------------------------------------
# Author: LEO CDP DevOps Team
# ----------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# ---- Configuration ----
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${BASE_DIR}/logs"
JAVA_BIN="$(command -v java)"
JAR_VERSION="v_0.9.0"
USER_EXPECTED="cdpsysuser"

# ---- Ensure correct user ----
if [[ "$(whoami)" != "$USER_EXPECTED" ]]; then
  echo "❌ Please run this script as ${USER_EXPECTED} user."
  echo "👉 Example: sudo su - ${USER_EXPECTED}"
  exit 1
fi

# ---- Create log directory ----
mkdir -p "${LOG_DIR}"

echo "-----------------------------------------"
echo "🧩 Starting LEO CDP Developer Environment"
echo "-----------------------------------------"
echo "Working directory : ${BASE_DIR}"
echo "Log directory     : ${LOG_DIR}"
echo "Java runtime      : ${JAVA_BIN}"
echo "JAR version       : ${JAR_VERSION}"
echo

# ---- Helper function ----
start_service() {
  local name=$1
  local jar=$2
  local port=$3
  local logfile="${LOG_DIR}/${name}.log"

  if pgrep -f "${jar}" >/dev/null 2>&1; then
    echo "⚠️  ${name} already running. Skipping..."
    return
  fi

  echo "🚀 Starting ${name} on port ${port}..."
  nohup ${JAVA_BIN} -jar "${BASE_DIR}/${jar}" > "${logfile}" 2>&1 &
  sleep 2
  echo "✅ ${name} started (PID: $(pgrep -f "${jar}"))"
  echo "   → Log: ${logfile}"
}

# ---- Start each service ----
start_service "Admin Service" "leo-main-starter-${JAR_VERSION}.jar" 9070
start_service "Observer Service" "leo-observer-starter-${JAR_VERSION}.jar" 9080
start_service "Scheduler Service" "leo-scheduler-starter-${JAR_VERSION}.jar" 9090
start_service "Data Processing Jobs" "leo-data-processing-starter-${JAR_VERSION}.jar" 9091

echo
echo "🎯 All LEO CDP dev services started successfully!"
echo "   Access Admin Dashboard → http://localhost:9070"
echo "   Access Data Hub API    → http://localhost:9080"
echo
echo "💾 Logs are located in: ${LOG_DIR}"
echo
echo "To stop all services, run:"
echo "   bash stop-server.sh"
echo "-----------------------------------------"