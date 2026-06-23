#!/bin/bash
set -euo pipefail

# -----------------------------
# Install ArangoDB 3.11.14 Community on Ubuntu 22.04 / 24.04
# -----------------------------
# - Checks if ArangoDB is installed
# - Asks user confirmation for LEO CDP server
# - Installs ArangoDB 3.11.14 if not present
# NOTE: ArangoDB 3.11 reached EOL and its GPG key expired in early 2026.
#       This script uses [trusted=yes] to bypass the invalid EXPKEYSIG error.
# -----------------------------

ARANGO_VERSION="3.11.14-1"
ARANGO_REPO_LIST="/etc/apt/sources.list.d/arangodb.list"

echo "🔍 Checking for existing ArangoDB installation..."

if command -v arangod >/dev/null 2>&1; then
  echo "✅ ArangoDB is already installed: $(arangod --version | grep -m1 'ArangoDB')"
  echo "Skipping installation."
  exit 0
fi

# Ask user if this server is for LEO CDP database
read -rp "❓ Is this server intended for the LEO CDP database? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "🚫 Installation cancelled by user."
  exit 0
fi

echo "📦 Proceeding with ArangoDB ${ARANGO_VERSION} installation..."

# Ensure required dependencies
sudo apt-get update -qq
sudo apt-get install -y curl apt-transport-https ca-certificates

# Overwrite the ArangoDB repository list to bypass the expired GPG key.
# By using [trusted=yes], APT will ignore the expired EXPKEYSIG signature.
# This replaces the previous configuration that caused the failure.
echo "🧩 Configuring ArangoDB repository (GPG verification disabled due to EOL)..."
echo "deb [trusted=yes] https://download.arangodb.com/arangodb311/DEBIAN/ /" \
  | sudo tee "$ARANGO_REPO_LIST" >/dev/null

# Update package index, explicitly allowing insecure repositories so the 
# expired key doesn't halt the update process
echo "🔄 Updating package index..."
sudo apt-get update -qq --allow-insecure-repositories

# Install the specific version of ArangoDB. 
# The --allow-unauthenticated flag ensures APT doesn't pause to prompt for 
# manual confirmation regarding the untrusted repository.
echo "☕ Installing ArangoDB ${ARANGO_VERSION}..."
sudo apt-get install -y --allow-unauthenticated "arangodb3=${ARANGO_VERSION}"

# Verify the installation was successful
echo "✅ Verifying ArangoDB installation..."
arangod --version

echo "🎉 ArangoDB ${ARANGO_VERSION} installed successfully for LEO CDP."
