#!/usr/bin/env bash
set -euo pipefail

# Run this script as root or with sudo
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root: sudo bash install-leo-cdp.sh"
  exit 1
fi

USERNAME="cdpsysuser"
BUILD_DIR="/build/cdp-instance"

echo "=============================================="
echo "  🚀 LEO CDP for Single Node - New Installation Started"
echo "=============================================="

# 1. Create system user (idempotent)
bash setup-cdp-system-user.sh

# 2. Install system dependencies
cd script-new-installation

echo "📦 Installing Dependencies..."
bash install-java.sh
bash install-redis.sh
bash install-database.sh
bash install-nginx.sh

echo "✅ Dependencies Installed"

# 3. Prepare CDP Instance Directory
echo "📁 Preparing Instance Directory: $BUILD_DIR"

mkdir -p "$BUILD_DIR"
chown -R "$USERNAME:$USERNAME" /build

# 4. Run CDP configuration as CDP user
echo "🔧 Running CDP Metadata & DB setup as $USERNAME..."

sudo -u "$USERNAME" bash -c "
  cd $BUILD_DIR
  bash setup-leocdp-metadata.sh
  bash setup-leocdp-database.sh
"

echo "✅ CDP Metadata & Database Configured"

# 5. Start CDP services
echo "🚀 Starting LEO CDP Services..."

sudo -u "$USERNAME" bash -c "
  cd $BUILD_DIR
  bash start-admin.sh
  bash start-observer.sh
  bash start-data-connector-jobs.sh
"

echo "🎉 LEO CDP Installation Completed Successfully!"
echo "=============================================="
echo "=============================================="