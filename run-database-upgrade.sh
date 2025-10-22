#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ----------------------------------------------------------
# 🧠 run-database-upgrade.sh
# Drop one or more ArangoDB collections and run LEO CDP system upgrade
# ----------------------------------------------------------
# Usage:
#   ./run-database-upgrade.sh <config_json_path> <db_config_key> <drop_collection_names>
# Example:
#   ./run-database-upgrade.sh ./configs/DEV-database-configs.json localCdpDbConfigs "cdp_dataservice,cdp_event_logs"
# ----------------------------------------------------------

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <config_json_path> <db_config_key> <comma_separated_collection_names>"
  echo "Example: $0 ./configs/DEV-database-configs.json localCdpDbConfigs \"cdp_dataservice,cdp_event_logs\""
  exit 1
fi

# --- Parameters ---
CONFIG_PATH="$1"
DB_CONFIG_KEY="$2"
DROP_COLLECTIONS="$3"

# --- Constants ---
BUILD_VERSION="v_0.9.0"
JAR_MAIN="leo-main-starter-${BUILD_VERSION}.jar"
LOG_FILE="./upgrade-leocdp.log"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $*" | tee -a "$LOG_FILE"; }

# --- Verify required tools ---
for bin in jq curl nc java; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    log "❌ Required tool '$bin' not found. Please install it first."
    exit 1
  fi
done

# --- Validate config file ---
if [[ ! -f "$CONFIG_PATH" ]]; then
  log "❌ Config file not found: $CONFIG_PATH"
  exit 1
fi

# --- Extract DB config dynamically using DB_CONFIG_KEY ---
ARANGO_USER=$(jq -r ".configs[\"${DB_CONFIG_KEY}\"].username" "$CONFIG_PATH")
ARANGO_PASS=$(jq -r ".configs[\"${DB_CONFIG_KEY}\"].password" "$CONFIG_PATH")
ARANGO_DB=$(jq -r ".configs[\"${DB_CONFIG_KEY}\"].database" "$CONFIG_PATH")
ARANGO_HOST=$(jq -r ".configs[\"${DB_CONFIG_KEY}\"].host" "$CONFIG_PATH")
ARANGO_PORT=$(jq -r ".configs[\"${DB_CONFIG_KEY}\"].port" "$CONFIG_PATH")

# --- Validate extracted values ---
if [[ -z "$ARANGO_HOST" || -z "$ARANGO_PORT" || -z "$ARANGO_USER" || -z "$ARANGO_PASS" || -z "$ARANGO_DB" ]]; then
  log "❌ Missing or invalid DB configuration for key '$DB_CONFIG_KEY' in $CONFIG_PATH"
  exit 1
fi

ENDPOINT="tcp://${ARANGO_HOST}:${ARANGO_PORT}"

log "----------------------------------------------------------"
log "🔧 Using DB Config Key: $DB_CONFIG_KEY"
log "  Host      : $ARANGO_HOST:$ARANGO_PORT"
log "  Database  : $ARANGO_DB"
log "  User      : $ARANGO_USER"
log "  Drop list : $DROP_COLLECTIONS"
log "----------------------------------------------------------"

# --- Check Java ---
JAVA_VERSION_OUTPUT=$(java -version 2>&1)
if ! echo "$JAVA_VERSION_OUTPUT" | grep -q 'version "11'; then
  log "❌ Java 11 required. Detected version:"
  echo "$JAVA_VERSION_OUTPUT" | tee -a "$LOG_FILE"
  exit 1
fi
log "✅ Java 11 detected."

# --- Check JAR existence ---
if [[ ! -f "$JAR_MAIN" ]]; then
  log "❌ $JAR_MAIN not found in current directory: $(pwd)"
  exit 1
fi

# --- Check ArangoDB connectivity ---
log "Checking ArangoDB connection to ${ARANGO_HOST}:${ARANGO_PORT}..."
if ! nc -z "$ARANGO_HOST" "$ARANGO_PORT" >/dev/null 2>&1; then
  log "❌ Cannot connect to ArangoDB at ${ARANGO_HOST}:${ARANGO_PORT}"
  exit 1
fi
log "✅ Connection to ArangoDB OK."

# --- Drop each collection ---
IFS=',' read -ra COLLECTIONS <<< "$DROP_COLLECTIONS"
for COLLECTION_NAME in "${COLLECTIONS[@]}"; do
  COLLECTION_NAME=$(echo "$COLLECTION_NAME" | xargs)  # trim spaces
  log "🔎 Checking collection '${COLLECTION_NAME}'..."
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "${ARANGO_USER}:${ARANGO_PASS}" \
    "http://${ARANGO_HOST}:${ARANGO_PORT}/_db/${ARANGO_DB}/_api/collection/${COLLECTION_NAME}")

  case "$HTTP_STATUS" in
    200)
      log "📦 Dropping collection '${COLLECTION_NAME}'..."
      DROP_RESPONSE=$(curl -s -u "${ARANGO_USER}:${ARANGO_PASS}" \
        -X DELETE "http://${ARANGO_HOST}:${ARANGO_PORT}/_db/${ARANGO_DB}/_api/collection/${COLLECTION_NAME}")
      if echo "$DROP_RESPONSE" | grep -q '"error":false'; then
        log "✅ Collection '${COLLECTION_NAME}' dropped successfully."
      else
        log "⚠️ Drop request sent but check response below:"
        echo "$DROP_RESPONSE" | tee -a "$LOG_FILE"
      fi
      ;;
    404)
      log "ℹ️  Collection '${COLLECTION_NAME}' does not exist. Skipping."
      ;;
    *)
      log "❌ Unexpected HTTP status ${HTTP_STATUS} for collection '${COLLECTION_NAME}'."
      exit 1
      ;;
  esac
done

# --- Run upgrade ---
log "🚀 Running LEO CDP system upgrade..."
java -jar "$JAR_MAIN" upgrade-system >> "$LOG_FILE" 2>&1
log "🎉 LEO CDP system upgrade completed successfully."