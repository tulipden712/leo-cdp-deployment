#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/trieu/leo-cdp-deployment.git"
TARGET_DIR="/build/cdp-instance"
SYSTEM_USER="cdpsysuser"

echo "[INFO] Checking if system user '$SYSTEM_USER' exists..."
if id "$SYSTEM_USER" &>/dev/null; then
  echo "[OK] User exists"
else
  echo "[INFO] User not found. Creating user with sudo NOPASSWD..."
  sudo useradd "$SYSTEM_USER" -s /bin/bash -p '*'
  sudo passwd -d "$SYSTEM_USER"
  sudo usermod -aG sudo "$SYSTEM_USER"
  echo "$SYSTEM_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers >/dev/null
  echo "[OK] User '$SYSTEM_USER' created with passwordless sudo"
fi

echo "[INFO] Creating target directory: $TARGET_DIR ..."
sudo mkdir -p "$TARGET_DIR"
sudo chown -R "$SYSTEM_USER":"$SYSTEM_USER" "$TARGET_DIR"

echo "[INFO] Switching to $SYSTEM_USER and cloning repository..."
sudo -u "$SYSTEM_USER" bash <<EOF
  set -e
  cd "$TARGET_DIR"

  if [ -d "$TARGET_DIR/.git" ]; then
    echo "[WARN] Existing git repo found. Removing old content..."
    rm -rf "$TARGET_DIR"/*
  fi

  git clone "$REPO_URL" "$TARGET_DIR"
EOF

echo "[INFO] Fixing permissions..."
sudo chown -R "$SYSTEM_USER":"$SYSTEM_USER" "$TARGET_DIR"
sudo chmod -R 755 "$TARGET_DIR"

echo "[✅ DONE] Repository cloned into $TARGET_DIR as $SYSTEM_USER"
echo "--------------------------"