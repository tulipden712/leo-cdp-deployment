#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ------------------------------------------------------
# 🧩 LEO CDP Stop Script
# Safely stops running LEO CDP services (Admin, Observer, Scheduler)
# ------------------------------------------------------

LOG_FILE="./leocdp-stop.log"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(timestamp)] $*" | tee -a "$LOG_FILE"
}

stop_service() {
  local prefix="$1"
  local description="$2"

  local pid
  pid=$(pgrep -f "java.*${prefix}" || true)

  if [[ -n "$pid" ]]; then
    log "Stopping ${description} (prefix=${prefix}) PID ${pid}..."
    kill -15 "$pid" 2>/dev/null || true
    sleep 4

    if ps -p "$pid" > /dev/null 2>&1; then
      log "PID ${pid} still alive, forcing kill..."
      kill -9 "$pid" 2>/dev/null || true
    else
      log "${description} stopped successfully."
    fi
  else
    log "No active process found for ${description}."
  fi
}

log "---------------- LEO CDP Shutdown Started ----------------"

# === ADMIN ===
stop_service "leocdp-admin" "LEO CDP Admin Service"

# === OBSERVER ===
stop_service "datahub" "LEO Data Observer"

# === JOB SCHEDULER ===
stop_service "DataConnectorScheduler" "LEO CDP Job Scheduler"

# === Any remaining LEO processes ===
leftover_pids=$(pgrep -f "leo-" || true)
if [[ -n "$leftover_pids" ]]; then
  log "Killing remaining LEO processes: ${leftover_pids}"
  kill -15 $leftover_pids 2>/dev/null || true
  sleep 3
  kill -9 $leftover_pids 2>/dev/null || true
else
  log "No leftover LEO processes found."
fi

log "✅ All LEO CDP services have been stopped."
log "----------------------------------------------------------"