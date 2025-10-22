#!/usr/bin/env bash
set -euo pipefail

# === CONFIGURATION ===
LEO_CDP_FOLDER="/build/cdp-instance"
BUILD_VERSION="v_0.9.0"
HTTP_ROUTER_KEY="leocdp_admin"
JAR_MAIN="leo-main-starter-${BUILD_VERSION}.jar"

JVM_PARAMS="-Xms256m -Xmx1500m -XX:+TieredCompilation -XX:+UseCompressedOops -XX:+DisableExplicitGC -XX:+UseNUMA -server"

LOG_DIR="${LEO_CDP_FOLDER}/logs"
LOG_FILE="${LOG_DIR}/admin-${HTTP_ROUTER_KEY}.log"
MAX_LOG_DAYS=7  # keep 7 days of rotated logs

# === PREPARE ENVIRONMENT ===
mkdir -p "$LOG_DIR"
cd "$LEO_CDP_FOLDER" || { echo "ERROR: Folder not found: $LEO_CDP_FOLDER"; exit 1; }

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

# === LOG ROTATION ===
if [ -f "$LOG_FILE" ]; then
  MOD_DATE=$(date -r "$LOG_FILE" +%Y-%m-%d)
  TODAY=$(date +%Y-%m-%d)
  if [ "$MOD_DATE" != "$TODAY" ]; then
    ARCHIVE="${LOG_FILE}.${MOD_DATE}.gz"
    echo "[$(timestamp)] Rotating old log → $ARCHIVE" >> "$LOG_FILE"
    gzip -c "$LOG_FILE" > "$ARCHIVE" && : > "$LOG_FILE"
  fi
fi

# Cleanup old gz logs
find "$LOG_DIR" -type f -name "admin-${HTTP_ROUTER_KEY}.log.*.gz" -mtime +${MAX_LOG_DAYS} -delete

echo "[$(timestamp)] === Restarting service: $HTTP_ROUTER_KEY ===" >> "$LOG_FILE"

# === PROCESS CONTROL ===
PID=$(pgrep -f "java.*${HTTP_ROUTER_KEY}" || true)
if [ -n "$PID" ]; then
  echo "[$(timestamp)] Stopping existing process PID $PID" >> "$LOG_FILE"
  kill -15 "$PID" || true
  sleep 4
fi

# === START NEW INSTANCE ===
echo "[$(timestamp)] Starting new process..." >> "$LOG_FILE"
nohup java $JVM_PARAMS -jar "$JAR_MAIN" "$HTTP_ROUTER_KEY" >> "$LOG_FILE" 2>&1 &

echo "[$(timestamp)] Started $HTTP_ROUTER_KEY (PID: $!)" >> "$LOG_FILE"
# === DONE ===