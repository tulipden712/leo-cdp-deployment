#!/usr/bin/bash
set -euo pipefail

echo "----------------------------------------------------------"
echo "[INFO] Installing ArangoDB client tools and dependencies..."
echo "----------------------------------------------------------"

# --- Ensure prerequisites ---
echo "[STEP] Checking base utilities..."
sudo apt-get update -qq
sudo apt-get install -y curl gnupg lsb-release ca-certificates jq netcat-openbsd > /dev/null 2>&1 || {
  echo "[ERROR] Failed to install base dependencies (curl, gnupg, jq, nc)."
  exit 1
}

# --- Detect Ubuntu codename ---
UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "jammy")
ARANGO_VERSION="3.11"

echo "[INFO] Ubuntu codename detected: ${UBUNTU_CODENAME}"
echo "[INFO] Setting up ArangoDB repository for version ${ARANGO_VERSION}"

# --- Add ArangoDB GPG key ---
sudo mkdir -p /usr/share/keyrings
curl -fsSL "https://download.arangodb.com/arangodb${ARANGO_VERSION//./}/DEBIAN/Release.key" \
  | sudo gpg --dearmor -o /usr/share/keyrings/arangodb-archive-keyring.gpg

# --- Add ArangoDB repository ---
echo "deb [signed-by=/usr/share/keyrings/arangodb-archive-keyring.gpg] \
https://download.arangodb.com/arangodb${ARANGO_VERSION//./}/DEBIAN/ /" \
| sudo tee /etc/apt/sources.list.d/arangodb.list > /dev/null

# --- Install ArangoDB client ---
echo "[STEP] Installing arangodb3-client (only tools, no server)..."
sudo apt-get update -qq
sudo apt-get install -y arangodb3-client > /dev/null 2>&1 || {
  echo "[ERROR] Failed to install arangodb3-client."
  exit 1
}

# --- Verification ---
echo "[STEP] Verifying installation..."
if command -v arangodump >/dev/null 2>&1; then
  echo "[SUCCESS] arangodump installed successfully."
  arangodump --version
else
  echo "[ERROR] arangodump not found after installation."
  exit 1
fi

if command -v jq >/dev/null 2>&1 && command -v nc >/dev/null 2>&1; then
  echo "[SUCCESS] jq and nc are available."
else
  echo "[WARNING] jq or nc missing — attempting reinstall..."
  sudo apt-get install -y jq netcat-openbsd
fi

echo "----------------------------------------------------------"
echo "[DONE] All required tools are installed and verified."
echo "----------------------------------------------------------"