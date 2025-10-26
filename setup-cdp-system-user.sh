#!/usr/bin/env bash
set -euo pipefail

# ==============================
# Configurable variables
# ==============================
USERNAME="cdpsysuser"
SSH_PUBLIC_KEY=""   # <-- set your public key here; if empty, SSH setup is skipped

# ==============================
# Create system user
# ==============================
if ! id -u "$USERNAME" >/dev/null 2>&1; then
  sudo useradd "$USERNAME" -m -s /bin/bash
  echo "✅ User $USERNAME created"
else
  echo "ℹ️ User $USERNAME already exists"
fi

HOME_DIR="/home/$USERNAME"
sudo mkdir -p "$HOME_DIR"
sudo chown -R "$USERNAME:$USERNAME" "$HOME_DIR"

# Remove password for the user (forces key login)
sudo passwd -d "$USERNAME" 2>/dev/null || true

# ==============================
# Add user to sudo group
# ==============================
if groups "$USERNAME" | grep -qw "sudo"; then
  echo "ℹ️ $USERNAME already in sudo group"
else
  sudo usermod -aG sudo "$USERNAME"
  echo "✅ Added $USERNAME to sudo group"
fi

# ==============================
# Setup passwordless sudo via /etc/sudoers.d
# ==============================
SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
if [ ! -f "$SUDOERS_FILE" ]; then
  echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | sudo tee "$SUDOERS_FILE" >/dev/null
  sudo chmod 440 "$SUDOERS_FILE"
  echo "✅ Sudoers entry created at $SUDOERS_FILE"
else
  echo "ℹ️ Sudoers rule already exists at $SUDOERS_FILE"
fi

# ==============================
# Setup SSH Key ONLY if provided
# ==============================
if [[ -n "$SSH_PUBLIC_KEY" ]]; then
  SSH_DIR="$HOME_DIR/.ssh"
  AUTH_KEYS="$SSH_DIR/authorized_keys"

  sudo mkdir -p "$SSH_DIR"
  sudo chmod 700 "$SSH_DIR"

  # Only add key if it's not already present
  if [ -f "$AUTH_KEYS" ] && grep -qxF "$SSH_PUBLIC_KEY" "$AUTH_KEYS"; then
    echo "ℹ️ SSH key already exists, skipping"
  else
    echo "$SSH_PUBLIC_KEY" | sudo tee -a "$AUTH_KEYS" >/dev/null
    sudo chmod 600 "$AUTH_KEYS"
    echo "✅ SSH key installed for $USERNAME"
  fi
  
  sudo chown -R "$USERNAME:$USERNAME" "$SSH_DIR"
else
  echo "⏭️ SSH_PUBLIC_KEY is empty → Skipping SSH setup"
fi

echo "🎉 Default '$USERNAME' system user setup for LEO CDP completed successfully"
