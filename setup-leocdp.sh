#!/bin/bash
# ---------------------------------------------------------------------------
#  LEO CDP - Multi Node Deployment Setup Script
# ---------------------------------------------------------------------------
#  Supports 3 main nodes:
#    1. cdp-database  : ArangoDB & Data Connector Jobs
#    2. cdp-datahub   : Observer Service
#    3. cdp-admin     : Admin Service
#
#  Author: LEO AI Lab
#  Version: 0.9.0
#  Date: 2025-10-30
# ---------------------------------------------------------------------------

set -e  # stop on error
set -o pipefail

BUILD_DIR="/build/cdp-instance"
SCRIPT_DIR="$BUILD_DIR/script-new-installation"
CONFIG_DIR="$BUILD_DIR/configs"
METADATA_FILE="$BUILD_DIR/leocdp-metadata-tpl.properties"
SYS_USER="cdpsysuser"

# ---------------------------------------------------------------------------
# Helper function to display section titles
# ---------------------------------------------------------------------------
log_section() {
  echo ""
  echo "=================================================================="
  echo ">>> $1"
  echo "=================================================================="
  echo ""
}

# ---------------------------------------------------------------------------
# 0. Pre-flight checks
# ---------------------------------------------------------------------------
log_section "Checking prerequisites..."

if [ ! -d "$BUILD_DIR" ]; then
  echo "❌ ERROR: Directory $BUILD_DIR not found. Please git clone LEO CDP release repo first:"
  echo "    sudo mkdir -p /build && cd /build"
  echo "    sudo git clone https://github.com/trieu/leo-cdp-framework.git cdp-instance"
  exit 1
fi

cd "$BUILD_DIR"

# ---------------------------------------------------------------------------
# 1. Create system user
# ---------------------------------------------------------------------------
log_section "Creating system user: $SYS_USER"

if id "$SYS_USER" &>/dev/null; then
  echo "User $SYS_USER already exists. Skipping..."
else
  sudo ./setup-cdp-system-user.sh
fi

# ---------------------------------------------------------------------------
# 2. Assign ownership of /build/cdp-instance
# ---------------------------------------------------------------------------
log_section "Setting permissions on $BUILD_DIR"

sudo chown -R "$SYS_USER:$SYS_USER" "$BUILD_DIR"
sudo chmod -R 755 "$BUILD_DIR"

# ---------------------------------------------------------------------------
# 3. Install Java & Redis
# ---------------------------------------------------------------------------
log_section "Installing Java and Redis (required on all nodes)"

sudo bash "$SCRIPT_DIR/install-java.sh"
sudo bash "$SCRIPT_DIR/install-redis.sh"

# ---------------------------------------------------------------------------
# 4. Detect server role
# ---------------------------------------------------------------------------
echo ""
echo "-----------------------------------------------------------"
echo "Which server role is this node?"
echo "  1) Database Server (ArangoDB)"
echo "  2) DataHub Server (Observer)"
echo "  3) Admin Server"
echo "-----------------------------------------------------------"
read -p "Enter the server role number [1/2/3]: " SERVER_ROLE
echo ""

# ---------------------------------------------------------------------------
# 5. Role-specific setups
# ---------------------------------------------------------------------------

# --- DATABASE NODE ---------------------------------------------------------
if [ "$SERVER_ROLE" == "1" ]; then
  log_section "Setting up Database Node (ArangoDB + Data Connector Jobs)"

  echo "Running ArangoDB installation..."
  sudo bash "$SCRIPT_DIR/install-database.sh"

  echo "Setting up LEO CDP database schema..."
  sudo bash "$BUILD_DIR/setup-leocdp-database.sh"

  if [ ! -f "$METADATA_FILE" ]; then
    echo "❌ ERROR: $METADATA_FILE not found after DB setup. Check installation logs."
    exit 1
  fi

  echo "✅ Database metadata file created: $METADATA_FILE"
  echo ""
  echo "Please open $CONFIG_DIR/PRO-database-configs.json"
  echo "and set the ArangoDB root password from $METADATA_FILE."
  echo ""

  echo "Now copying metadata template for all servers..."
  sudo cp "$METADATA_FILE" "$BUILD_DIR/leocdp-metadata-tpl.properties"

  echo "Starting Data Connector Jobs in background..."
  nohup sudo -u "$SYS_USER" bash "$BUILD_DIR/start-data-connector-jobs.sh" >/var/log/leocdp-datajob.log 2>&1 &
  echo "✅ Data connector jobs started."

fi

# --- DATAHUB NODE ----------------------------------------------------------
if [ "$SERVER_ROLE" == "2" ]; then
  log_section "Setting up DataHub Node (Observer Service)"

  if [ ! -f "$METADATA_FILE" ]; then
    echo "❌ ERROR: Metadata file missing. Please copy leocdp-metadata-tpl.properties from the database server."
    exit 1
  fi

  echo "Starting Observer Service..."
  nohup sudo -u "$SYS_USER" bash "$BUILD_DIR/start-observer.sh" >/var/log/leocdp-observer.log 2>&1 &
  echo "✅ Observer service started."
fi

# --- ADMIN NODE ------------------------------------------------------------
if [ "$SERVER_ROLE" == "3" ]; then
  log_section "Setting up Admin Node"

  if [ ! -f "$METADATA_FILE" ]; then
    echo "❌ ERROR: Metadata file missing. Please copy leocdp-metadata-tpl.properties from the database server."
    exit 1
  fi

  echo "Starting Admin Service..."
  nohup sudo -u "$SYS_USER" bash "$BUILD_DIR/start-admin.sh" >/var/log/leocdp-admin.log 2>&1 &
  echo "✅ Admin service started."
fi

# ---------------------------------------------------------------------------
# 6. Summary
# ---------------------------------------------------------------------------
log_section "Setup completed successfully 🎉"

echo "Summary:"
echo "  - Git repo path       : $BUILD_DIR"
echo "  - System user         : $SYS_USER"
echo "  - Metadata file       : $METADATA_FILE"
echo "  - Config directory    : $CONFIG_DIR"
echo ""
echo "Check logs in /var/log for service outputs."
echo "Remember to ensure that all nodes share the same leocdp-metadata-tpl.properties."
echo ""

exit 0
