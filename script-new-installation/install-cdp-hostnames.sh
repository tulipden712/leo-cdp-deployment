#!/bin/bash
# ======================================================
# 🧩 LEO CDP Host Configuration Script
# Add required CDP host entries into /etc/hosts safely
# ======================================================

# Define the block of hosts for CDP
CDP_HOSTS_BLOCK=$(cat <<'EOF'
# BEGIN CDP hosts
172.20.172.36 cdp-database
172.20.172.35 cdp-datahub
172.20.172.37 cdp-admin cdp-redis
# END CDP hosts
EOF
)

# Function to append hosts safely
add_hosts_block() {
  echo "🔍 Checking /etc/hosts for existing LEO CDP block..."
  if grep -q "BEGIN CDP hosts" /etc/hosts; then
    echo "⚙️  Existing CDP host entries found. Updating block..."
    # Remove old block
    sudo sed -i '/BEGIN CDP hosts/,/END CDP hosts/d' /etc/hosts
  fi

  echo "🧱 Adding new CDP host entries..."
  echo "" | sudo tee -a /etc/hosts > /dev/null
  echo "$CDP_HOSTS_BLOCK" | sudo tee -a /etc/hosts > /dev/null

  echo "✅ CDP hosts updated successfully!"
  echo "📋 Current /etc/hosts entries for CDP:"
  grep "CDP" /etc/hosts
}

# Execute
add_hosts_block
