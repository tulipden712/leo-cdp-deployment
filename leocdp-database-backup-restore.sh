#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ----------------------------------------------------------
# 🧠 arangodb-backup-restore.sh
# Backup and restore ArangoDB databases (Community Edition 3.11)
# using JSON config file for connection details
# ----------------------------------------------------------
# Usage:
#   ./arangodb-backup-restore.sh backup /configs/DEV-database-configs.json <backup_folder>
#   ./arangodb-backup-restore.sh restore /configs/DEV-database-configs.json <backup_folder>
# ----------------------------------------------------------

if [[ $# -lt 3 ]]; then
  echo "Usage:"
  echo "  $0 backup <config_json_path> <backup_folder>"
  echo "  $0 restore <config_json_path> <backup_folder>"
  echo "Example:"
  echo "  $0 backup ./configs/DEV-database-configs.json ./backup_2025_10_22"
  exit 1
fi

# --- Command and parameters ---
COMMAND="$1"
CONFIG_PATH="$2"
BACKUP_FOLDER="$3"

LOG_FILE="./arangodb-backup-restore.log"
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $*" | tee -a "$LOG_FILE"; }

# --- Verify tools ---
for bin in jq arangodump arangorestore nc; do
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

# --- Extract DB config using jq ---
ARANGO_USER=$(jq -r '.configs.localCdpDbConfigs.username' "$CONFIG_PATH")
ARANGO_PASS=$(jq -r '.configs.localCdpDbConfigs.password' "$CONFIG_PATH")
ARANGO_DB=$(jq -r '.configs.localCdpDbConfigs.database' "$CONFIG_PATH")
ARANGO_HOST=$(jq -r '.configs.localCdpDbConfigs.host' "$CONFIG_PATH")
ARANGO_PORT=$(jq -r '.configs.localCdpDbConfigs.port' "$CONFIG_PATH")

# --- Validate extracted values ---
if [[ -z "$ARANGO_HOST" || -z "$ARANGO_PORT" || -z "$ARANGO_USER" || -z "$ARANGO_PASS" || -z "$ARANGO_DB" ]]; then
  log "❌ Missing required database configuration in $CONFIG_PATH"
  exit 1
fi

ENDPOINT="tcp://${ARANGO_HOST}:${ARANGO_PORT}"

log "----------------------------------------------------------"
log "Using database config from: $CONFIG_PATH"
log "Database: $ARANGO_DB"
log "Host: $ARANGO_HOST:$ARANGO_PORT"
log "User: $ARANGO_USER"
log "----------------------------------------------------------"

# --- Check ArangoDB connectivity ---
log "Checking ArangoDB endpoint at ${ENDPOINT}..."
if ! nc -z "$ARANGO_HOST" "$ARANGO_PORT" >/dev/null 2>&1; then
  log "❌ Cannot connect to ArangoDB at ${ENDPOINT}"
  exit 1
fi
log "✅ Connection OK."

# --- Backup function ---
backup_database() {
  mkdir -p "$BACKUP_FOLDER"
  log "🚀 Starting ArangoDB backup for database '${ARANGO_DB}'..."
  arangodump \
    --server.endpoint "$ENDPOINT" \
    --server.username "$ARANGO_USER" \
    --server.password "$ARANGO_PASS" \
    --server.database "$ARANGO_DB" \
    --output-directory "$BACKUP_FOLDER" \
    --overwrite true \
    --progress true | tee -a "$LOG_FILE"
  log "✅ Backup completed successfully → $BACKUP_FOLDER"
}

# --- Restore function ---
restore_database() {
  if [[ ! -d "$BACKUP_FOLDER" ]]; then
    log "❌ Backup folder not found: $BACKUP_FOLDER"
    exit 1
  fi
  log "🚀 Starting ArangoDB restore to database '${ARANGO_DB}'..."
  arangorestore \
    --server.endpoint "$ENDPOINT" \
    --server.username "$ARANGO_USER" \
    --server.password "$ARANGO_PASS" \
    --server.database "$ARANGO_DB" \
    --input-directory "$BACKUP_FOLDER" \
    --progress true \
    --overwrite true | tee -a "$LOG_FILE"
  log "✅ Restore completed successfully from: $BACKUP_FOLDER"
}

# --- Command dispatcher ---
case "$COMMAND" in
  backup)
    backup_database
    ;;
  restore)
    restore_database
    ;;
  *)
    log "❌ Invalid command: ${COMMAND}. Use 'backup' or 'restore'."
    exit 1
    ;;
esac

log "🎉 ArangoDB ${COMMAND} operation completed successfully."
