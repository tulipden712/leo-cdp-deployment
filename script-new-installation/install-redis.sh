#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Fix and install Redis 6.2.x (Open Source) on Ubuntu 22.04 / 24.04
# -----------------------------
REDIS_MAJOR_VERSION="6.2"
REDIS_REPO_LIST="/etc/apt/sources.list.d/redis.list"
REDIS_KEYRING_PATH="/usr/share/keyrings/redis-archive-keyring.gpg"
CODENAME=$(lsb_release -cs)

echo "🔍 Checking for Redis installation or conflicts..."

# 1. Remove conflicting Ubuntu packages
if dpkg -l | grep -q "redis-server"; then
  echo "⚠️ Removing conflicting Redis packages from Ubuntu repo..."
  sudo systemctl stop redis-server || true
  sudo apt-get remove --purge -y redis redis-server redis-tools || true
  sudo apt-get autoremove -y
  sudo apt-get clean
fi

# 2. Ensure required tools
sudo apt-get update -qq
sudo apt-get install -y curl ca-certificates gnupg lsb-release apt-transport-https

# 3. Add Redis official repo and key
if [ ! -f "$REDIS_KEYRING_PATH" ]; then
  echo "🔑 Adding Redis GPG key..."
  curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o "$REDIS_KEYRING_PATH"
else
  echo "🔑 Redis GPG key already exists."
fi

if [ ! -f "$REDIS_REPO_LIST" ]; then
  echo "🧩 Adding Redis repository..."
  echo "deb [signed-by=${REDIS_KEYRING_PATH}] https://packages.redis.io/deb ${CODENAME} main" \
    | sudo tee "$REDIS_REPO_LIST" >/dev/null
else
  echo "🧩 Redis repository already configured."
fi

# 4. Update and find 6.2.x package
sudo apt-get update -qq
AVAILABLE_62=$(apt-cache madison redis-server | grep '6\.2' | head -n1 | awk '{print $3}')

if [ -z "$AVAILABLE_62" ]; then
  echo "❌ No Redis 6.2.x version available for Ubuntu ${CODENAME}. Exiting."
  exit 1
fi

echo "📦 Installing Redis ${AVAILABLE_62}..."
sudo apt-get install -y --allow-downgrades "redis-server=${AVAILABLE_62}" "redis-tools=${AVAILABLE_62}"

# 5. Enable and start service
sudo systemctl enable redis-server
sudo systemctl restart redis-server

# 6. Verify installation
NEW_VERSION=$(redis-server --version | awk '{print $3}' | cut -d'=' -f2)
if [[ "$NEW_VERSION" == ${REDIS_MAJOR_VERSION}* ]]; then
  echo "🎉 Redis ${NEW_VERSION} installed successfully and running!"
else
  echo "❌ Installation failed or wrong version detected: ${NEW_VERSION}"
  exit 1
fi

# Optional: Prevent unwanted upgrades to 7.x
sudo apt-mark hold redis-server redis-tools

# Display service status
sudo systemctl --no-pager status redis-server | grep "Active:"
