#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ----------------------------------------------------------
# 🧠 run-database-backup-restore.sh
# Backup and restore ArangoDB databases (Community Edition 3.11)
# using JSON config file and DB_CONFIG_KEY
# ----------------------------------------------------------
# Usage:
#   ./run-database-backup-restore.sh backup <config_json_path> <db_config_key> [backup_folder]
#   ./run-database-backup-restore.sh restore <config_json_path> <db_config_key> <backup_folder>
# Example:
#   ./run-database-backup-restore.sh backup /configs/DEV-database-configs.json localCdpDbConfigs
# ----------------------------------------------------------

# --- Validate args ---
if [[ $# -lt 3 ]]; then
  echo "Usage:"
  echo "  $0 backup <config_json_path> <db_config_key> [backup_folder]"
  echo "  $0 restore <config_json_path> <db_config_key> <backup_folder>"
  echo "Example:"
  echo "  $0 backup /configs/DEV-database-configs.json localCdpDbConfigs"
  exit 1
fi

# --- Parameters ---
COMMAND="$1"
CONFIG_PATH="$2"
DB_CONFIG_KEY="$3"
BACKUP_FOLDER="${4:-}"

# --- Constants ---
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${BASE_DIR}/arangodb-backup-restore.log"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $*" | tee -a "$LOG_FILE"; }

# --- Verify required tools ---
for bin in jq arangodump arangorestore nc; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    log "❌ Required tool '$bin' not found. Please install it."
    exit 1
  fi
done

# --- Validate config file ---
if [[ ! -f "$CONFIG_PATH" ]]; then
  log "❌ Config file not found: $CONFIG_PATH"
  exit 1
fi

# --- Extract DB config dynamically ---
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

# --- Set default backup folder for CRON ---
if [[ -z "$BACKUP_FOLDER" && "$COMMAND" == "backup" ]]; then
  DATE_TAG=$(date '+%Y_%m_%d_%H%M')
  BACKUP_FOLDER="${BASE_DIR}/backup_${ARANGO_DB}_${DATE_TAG}"
fi

log "----------------------------------------------------------"
log "Operation : $COMMAND"
log "Config    : $CONFIG_PATH"
log "ConfigKey : $DB_CONFIG_KEY"
log "Database  : $ARANGO_DB"
log "Host      : $ARANGO_HOST:$ARANGO_PORT"
log "User      : $ARANGO_USER"
log "BackupDir : ${BACKUP_FOLDER:-<not applicable>}"
log "----------------------------------------------------------"

# --- Check ArangoDB connectivity ---
log "Checking ArangoDB endpoint ${ENDPOINT}..."
if ! nc -z "$ARANGO_HOST" "$ARANGO_PORT" >/dev/null 2>&1; then
  log "❌ Cannot connect to ArangoDB at ${ENDPOINT}"
  exit 1
fi
log "✅ ArangoDB reachable."

# --- Backup function ---
backup_database() {
  mkdir -p "$BACKUP_FOLDER"
  log "🚀 Starting ArangoDB backup for '${ARANGO_DB}'..."
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
  log "🚀 Starting ArangoDB restore for '${ARANGO_DB}'..."
  arangorestore \
    --server.endpoint "$ENDPOINT" \
    --server.username "$ARANGO_USER" \
    --server.password "$ARANGO_PASS" \
    --server.database "$ARANGO_DB" \
    --input-directory "$BACKUP_FOLDER" \
    --overwrite true \
    --progress true | tee -a "$LOG_FILE"
  log "✅ Restore completed successfully from $BACKUP_FOLDER"
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
    log "❌ Invalid command '$COMMAND'. Use 'backup' or 'restore'."
    exit 1
    ;;
esac

log "🎉 ArangoDB ${COMMAND} completed successfully."