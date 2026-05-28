#!/bin/bash
set -e

# --- Metadata ---
TEMPLATE_META_DATA="setup-leocdp-metadata-tpl.properties"
FINAL_LEO_META_DATA="leocdp-metadata.properties"

echo "──────────────────────────────────────────────"
echo "🚀 LEO CDP Production Config Setup"
echo "──────────────────────────────────────────────"

# --- Check template file ---
if [ ! -f "$TEMPLATE_META_DATA" ]; then
  echo "❌ Missing template: $TEMPLATE_META_DATA"
  exit 1
fi

# --- Ask user for info ---
read -rp "Enter HTTP Admin Domain (e.g., admin.leocdp.yourdomain.com): " httpAdminDomain
read -rp "Enter WebSocket Domain (e.g., ws.leocdp.yourdomain.com): " webSocketDomain
read -rp "Enter Data Observer Domain (e.g., data.leocdp.yourdomain.com): " httpObserverDomain
read -rp "Enter LEO Bot Domain (e.g., bot.leocdp.yourdomain.com): " httpLeoBotDomain
read -rp "Enter LEO Bot API Key: " httpLeoBotApiKey
read -rp "Enter Super Admin Email: " superAdminEmail

read -rp "Enter Admin Logo URL (leave empty for default): " adminLogoUrl
if [ -z "$adminLogoUrl" ]; then
  adminLogoUrl="https://cdn.jsdelivr.net/gh/USPA-Technology/leo-cdp-static-files@latest/images/leo-cdp-logo.png"
fi

echo ""
echo "----- SMTP Configuration -----"
read -rp "SMTP Host: " smtpHost
read -rp "SMTP Port: " smtpPort
read -rp "SMTP User: " smtpUser
read -rp "SMTP Password: " smtpPassword
read -rp "SMTP From Address: " smtpFromAddress

echo ""
echo "----- Database Backup Configuration -----"
read -rp "Database Backup Path: " databaseBackupPath
read -rp "Backup Period Hours (default 24): " databaseBackupPeriodHours
databaseBackupPeriodHours=${databaseBackupPeriodHours:-24}
read -rp "Backup Retention Days (default 7): " databaseBackupRetentionDays
databaseBackupRetentionDays=${databaseBackupRetentionDays:-7}

echo ""
echo "Generating production config from $TEMPLATE_META_DATA ..."
sleep 1

# --- Replace placeholders in template ---
sed \
  -e "s|{{httpAdminDomain}}|${httpAdminDomain}|g" \
  -e "s|{{webSocketDomain}}|${webSocketDomain}|g" \
  -e "s|{{httpObserverDomain}}|${httpObserverDomain}|g" \
  -e "s|{{httpLeoBotDomain}}|${httpLeoBotDomain}|g" \
  -e "s|{{httpLeoBotApiKey}}|${httpLeoBotApiKey}|g" \
  -e "s|{{superAdminEmail}}|${superAdminEmail}|g" \
  -e "s|{{adminLogoUrl}}|${adminLogoUrl}|g" \
  -e "s|{{smtpHost}}|${smtpHost}|g" \
  -e "s|{{smtpPort}}|${smtpPort}|g" \
  -e "s|{{smtpUser}}|${smtpUser}|g" \
  -e "s|{{smtpPassword}}|${smtpPassword}|g" \
  -e "s|{{smtpFromAddress}}|${smtpFromAddress}|g" \
  -e "s|{{databaseBackupPath}}|${databaseBackupPath}|g" \
  -e "s|{{databaseBackupPeriodHours}}|${databaseBackupPeriodHours}|g" \
  -e "s|{{databaseBackupRetentionDays}}|${databaseBackupRetentionDays}|g" \
  "$TEMPLATE_META_DATA" > "$FINAL_LEO_META_DATA"

echo "✅ Created $FINAL_LEO_META_DATA"

# --- Add to .gitignore if not already ---
if ! grep -qxF "$FINAL_LEO_META_DATA" .gitignore 2>/dev/null; then
  echo "$FINAL_LEO_META_DATA" >> .gitignore
  echo "📁 Added $FINAL_LEO_META_DATA to .gitignore"
fi

# --- Confirm result ---
echo "\n ───────────────────────────────────────────"
echo "✅ LEO CDP production metadata generated."
echo "📄 Path: $(realpath "$FINAL_LEO_META_DATA")"
echo "──────────────────────────────────────────────"
echo "Preview of generated file:"
echo "──────────────────────────────────────────────"
head -n 30 "$FINAL_LEO_META_DATA"
echo "──────────────────────────────────────────────"