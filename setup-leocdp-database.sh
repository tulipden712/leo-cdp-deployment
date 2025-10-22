#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ---------------------------------------
# 🧠 LEO CDP Database Setup Script
# ---------------------------------------
BUILD_VERSION="v_0.9.0"
JAR_MAIN="leo-main-starter-${BUILD_VERSION}.jar"
METADATA_FILE="./leocdp-metadata.properties"
METADATA_SETUP_SCRIPT="./setup-leocdp-metadata.sh"

# --- Helper: print colored messages ---
info()    { echo -e "\033[1;34m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

# --- Verify JAR existence ---
if [[ ! -f "$JAR_MAIN" ]]; then
  error "$JAR_MAIN not found in current directory: $(pwd)"
  exit 1
fi

# --- Verify Java installation ---
if ! command -v java &>/dev/null; then
  error "Java not found. Please install Java 11 before running this script."
  exit 1
fi

# --- Verify Java version = 11 ---
JAVA_VERSION_OUTPUT=$(java -version 2>&1)
if ! echo "$JAVA_VERSION_OUTPUT" | grep -q 'version "11'; then
  error "Invalid Java version detected. Required: Java 11"
  echo "Detected:"
  echo "$JAVA_VERSION_OUTPUT"
  exit 1
fi
info "✅ Java 11 detected."

# --- Check leocdp-metadata.properties existence ---
if [[ ! -f "$METADATA_FILE" ]]; then
  info "⚙️ $METADATA_FILE not found."
  if [[ -x "$METADATA_SETUP_SCRIPT" ]]; then
    info "Running metadata setup script: $METADATA_SETUP_SCRIPT"
    bash "$METADATA_SETUP_SCRIPT"
  else
    error "$METADATA_SETUP_SCRIPT not found or not executable."
    echo "Please create $METADATA_FILE manually or provide the setup script."
    exit 1
  fi
fi

# --- Verify required configs exist ---
required_keys=("superAdminEmail" "mainDatabaseConfig" "systemDatabaseConfig")
for key in "${required_keys[@]}"; do
  if ! grep -q "^${key}=" "$METADATA_FILE"; then
    error "Missing key '$key' in $METADATA_FILE"
    exit 1
  fi
done
success "✅ leocdp-metadata.properties validated."

# --- Prompt for Super Admin Password ---
info "🚀 Starting LEO CDP System Setup"
echo "----------------------------------"

read -rsp "Enter the superadmin password: " superadmin_password
echo ""
read -rsp "Confirm password: " superadmin_password_confirm
echo ""

if [[ "$superadmin_password" != "$superadmin_password_confirm" ]]; then
  error "Passwords do not match. Exiting setup."
  exit 1
fi

if [[ -z "$superadmin_password" ]]; then
  error "Password cannot be empty."
  exit 1
fi

# --- Run setup ---
info "🔑 Running system database setup..."
set +e
java -jar "$JAR_MAIN" setup-system-with-password "$superadmin_password"
setup_exit_code=$?
set -e

if [[ $setup_exit_code -ne 0 ]]; then
  error "Database setup failed with exit code $setup_exit_code."
  exit $setup_exit_code
fi

success "🎉 LEO CDP Database setup completed successfully!"
