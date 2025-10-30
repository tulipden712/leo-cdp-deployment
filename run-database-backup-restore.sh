#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ----------------------------------------------------------
# 🧠 run-database-backup-restore.sh
# Backup and restore ArangoDB (Community Edition 3.11)
# Supports manual runs and CRON-based automated backups
# Automatically installs arangodb3-client if missing
# ----------------------------------------------------------
# Manual usage:
#   ./run-database-backup-restore.sh backup <config_json_path> <db_config_key> [backup_folder]
#   ./run-database-backup-restore.sh restore <config_json_path> <db_config_key> <backup_folder>
#
# CRON usage (auto defaults):
#   0 3 * * * /build/cdp-instance/run-database-backup-restore.sh backup >> /var/log/leocdp-backup.log 2>&1
# ----------------------------------------------------------

# --- Always work from /build/cdp-instance ---
cd /build/cdp-instance || {
  echo "❌ Cannot change directory to /build/cdp-instance"
  exit 1
}

# --- Detect invocation mode ---
if [[ $# -lt 1 ]]; then
  echo "Usage:"
  echo "  $0 backup <config_json_path> <db_config_key> [backup_folder]"
  echo "  $0 restore <config_json_path> <db_config_key> <backup_folder]"
  exit 1
fi

COMMAND="$1"

# --- Determine default or user-provided params ---
if [[ $# -ge 3 ]]; then
  CONFIG_PATH="$2"
  DB_CONFIG_KEY="$3"
  BACKUP_FOLDER="${4:-}"
else
  CONFIG_PATH="configs/PRO-database-configs.json"
  DB_CONFIG_KEY="cdpDbConfigs"
  DATE_TAG=$(date '+%Y-%m-%d-%H-%M')
  BACKUP_FOLDER="/home/cdpsysuser/backup-${DATE_TAG}"
fi

# --- Constants ---
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${BASE_DIR}/arangodb-backup-restore.log"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $*" | tee -a "$LOG_FILE"; }

# --- Verify required tools ---
check_tools() {
  local missing_tools=()
  for bin in jq arangodump arangorestore nc; do
    if ! command -v "$bin" >/dev/null 2>&1; then
      missing_tools+=("$bin")
    fi
  done

  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log "⚠️ Missing tools: ${missing_tools[*]}"
    if [[ -x "./setup-arangodb3-client.sh" ]]; then
      log "🔧 Running setup-arangodb3-client.sh to install missing tools..."
      ./setup-arangodb3-client.sh || {
        log "❌ Failed to install ArangoDB client tools."
        exit 1
      }
      log "✅ ArangoDB client tools installed successfully."
    else
      log "❌ setup-arangodb3-client.sh not found or not executable."
      exit 1
    fi
  fi
}
check_tools

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

# --- Default backup folder ---
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
log "Mode      : $( [[ $# -ge 3 ]] && echo 'Manual' || echo 'CRON' )"
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
