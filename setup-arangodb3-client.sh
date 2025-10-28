#!/usr/bin/bash
set -e

echo "[INFO] Installing ArangoDB client tools (arangodb3-client)..."

# Detect Ubuntu version codename (e.g. focal, jammy, noble)
UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")
ARANGO_VERSION="3.11"

echo "[INFO] Ubuntu codename detected: $UBUNTU_CODENAME"
echo "[INFO] Setting up ArangoDB repository for version $ARANGO_VERSION"

# Add GPG key
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://download.arangodb.com/arangodb${ARANGO_VERSION//./}/DEBIAN/Release.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/arangodb-archive-keyring.gpg

# Add repository
echo "deb [signed-by=/usr/share/keyrings/arangodb-archive-keyring.gpg] \
https://download.arangodb.com/arangodb${ARANGO_VERSION//./}/DEBIAN/ /" \
| sudo tee /etc/apt/sources.list.d/arangodb.list

# Update apt and install client only
sudo apt update
sudo apt install -y arangodb3-client

# Verify installation
if command -v arangodump >/dev/null 2>&1; then
  echo "[SUCCESS] arangodump installed successfully."
  arangodump --version
else
  echo "[ERROR] arangodump not found after installation."
  exit 1
fi
