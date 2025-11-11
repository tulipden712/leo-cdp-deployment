#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# ⚙️ CONFIGURATION
# ==========================================
LEO_CDP_FOLDER="/build/cdp-instance"
BUILD_VERSION="v_0.9.0"
HTTP_ROUTER_KEYS="leocdp_admin1 leocdp_admin2 leocdp_admin3"

JAR_MAIN="leo-main-starter-${BUILD_VERSION}.jar"
JVM_PARAMS="-Xms256m -Xmx1500m -XX:+TieredCompilation -XX:+UseCompressedOops -XX:+DisableExplicitGC -XX:+UseNUMA -server"

LOG_DIR="${LEO_CDP_FOLDER}/logs"
MAX_LOG_DAYS=7  # keep 7 days of rotated logs

# ==========================================
# 🧩 ENVIRONMENT PREPARATION
# ==========================================
mkdir -p "$LOG_DIR"
cd "$LEO_CDP_FOLDER" || { echo "❌ ERROR: Folder not found: $LEO_CDP_FOLDER"; exit 1; }

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

# ==========================================
# 🚀 LOOP THROUGH ALL ROUTER KEYS
# ==========================================
for HTTP_ROUTER_KEY in $HTTP_ROUTER_KEYS; do
  LOG_FILE="${LOG_DIR}/admin-${HTTP_ROUTER_KEY}.log"

  echo "[$(timestamp)] === Restarting service: ${HTTP_ROUTER_KEY} ===" | tee -a "$LOG_FILE"

  # === LOG ROTATION ===
  if [ -f "$LOG_FILE" ]; then
    MOD_DATE=$(date -r "$LOG_FILE" +%Y-%m-%d)
    TODAY=$(date +%Y-%m-%d)
    if [ "$MOD_DATE" != "$TODAY" ]; then
      ARCHIVE="${LOG_FILE}.${MOD_DATE}.gz"
      echo "[$(timestamp)] Rotating old log → $ARCHIVE" | tee -a "$LOG_FILE"
      gzip -c "$LOG_FILE" > "$ARCHIVE"
      : > "$LOG_FILE"  # truncate
    fi
  fi

  # Clean up old rotated logs
  find "$LOG_DIR" -type f -name "admin-${HTTP_ROUTER_KEY}.log.*.gz" -mtime +${MAX_LOG_DAYS} -delete

  # === PROCESS CONTROL ===
  PID=$(pgrep -f "java.*${HTTP_ROUTER_KEY}" || true)
  if [ -n "$PID" ]; then
    echo "[$(timestamp)] Stopping existing process PID $PID..." | tee -a "$LOG_FILE"
    kill -15 "$PID" || true
    sleep 4
  fi

  # === START NEW INSTANCE ===
  echo "[$(timestamp)] Starting new process [$HTTP_ROUTER_KEY]..." | tee -a "$LOG_FILE"
  nohup java $JVM_PARAMS -jar "$JAR_MAIN" "$HTTP_ROUTER_KEY" >> "$LOG_FILE" 2>&1 &
  NEW_PID=$!

  echo "[$(timestamp)] ✅ Started [$HTTP_ROUTER_KEY] (PID: $NEW_PID)" | tee -a "$LOG_FILE"
  echo "[$(timestamp)] ---------------------------------------------" | tee -a "$LOG_FILE"
done

echo "[$(timestamp)] ✅ All observer processes launched successfully."
