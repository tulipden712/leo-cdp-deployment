#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ----------------------------------------------------------
# 🧠 upgrade-database.sh
# Drop a collection in ArangoDB and run LEO CDP system upgrade
# ----------------------------------------------------------

# Usage:
# ./upgrade-database.sh <host> <port> <username> <password> <database> <collection>

if [[ $# -lt 6 ]]; then
  echo "Usage: $0 <host> <port> <username> <password> <database> <collection>"
  echo "Example:"
  echo "  $0 localhost 8529 root 12345678 leo_cdp_test cdp_dataservice"
  exit 1
fi

# --- Parameters ---
ARANGO_HOST="$1"
ARANGO_PORT="$2"
ARANGO_USER="$3"
ARANGO_PASS="$4"
ARANGO_DB="$5"
COLLECTION_NAME="$6"

# --- Constants ---
BUILD_VERSION="v_0.9.0"
JAR_MAIN="leo-main-starter-${BUILD_VERSION}.jar"
LOG_FILE="./upgrade-database.log"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $*" | tee -a "$LOG_FILE"; }

# --- Check Java ---
if ! command -v java &>/dev/null; then
  log "❌ Java not found. Please install Java 11 before running this script."
  exit 1
fi
JAVA_VERSION_OUTPUT=$(java -version 2>&1)
if ! echo "$JAVA_VERSION_OUTPUT" | grep -q 'version "11'; then
  log "❌ Invalid Java version detected. Required: Java 11."
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

# --- Check if collection exists ---
log "Checking if collection '${COLLECTION_NAME}' exists in database '${ARANGO_DB}'..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -u "${ARANGO_USER}:${ARANGO_PASS}" \
  "http://${ARANGO_HOST}:${ARANGO_PORT}/_db/${ARANGO_DB}/_api/collection/${COLLECTION_NAME}")

case "$HTTP_STATUS" in
  200)
    log "Collection '${COLLECTION_NAME}' found. Proceeding to drop..."
    DROP_RESPONSE=$(curl -s -u "${ARANGO_USER}:${ARANGO_PASS}" \
      -X DELETE "http://${ARANGO_HOST}:${ARANGO_PORT}/_db/${ARANGO_DB}/_api/collection/${COLLECTION_NAME}")
    if echo "$DROP_RESPONSE" | grep -q '"error":false'; then
      log "✅ Collection '${COLLECTION_NAME}' dropped successfully."
    else
      log "⚠️ Drop request completed but check response below:"
      echo "$DROP_RESPONSE" | tee -a "$LOG_FILE"
    fi
    ;;
  404)
    log "ℹ️ Collection '${COLLECTION_NAME}' does not exist. Nothing to drop."
    ;;
  *)
    log "❌ Unexpected HTTP status ${HTTP_STATUS} while checking collection."
    exit 1
    ;;
esac

# --- Run upgrade ---
log "🚀 Running LEO CDP system upgrade..."
set +e
java -jar "$JAR_MAIN" upgrade-system | tee -a "$LOG_FILE"
UPGRADE_EXIT_CODE=${PIPESTATUS[0]}
set -e

if [[ $UPGRADE_EXIT_CODE -ne 0 ]]; then
  log "❌ Upgrade failed with exit code ${UPGRADE_EXIT_CODE}."
  exit $UPGRADE_EXIT_CODE
fi

log "🎉 LEO CDP system upgrade completed successfully!"
