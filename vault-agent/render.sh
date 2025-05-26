#!/bin/bash

set -e

# ------------------------------------------------------------------------------
# 📁 Set working directory to the location of this script
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starting Vault Agent (one-shot mode) to render .env..."

# ------------------------------------------------------------------------------
# 📄 Load and export variables from .env.vault
# ------------------------------------------------------------------------------
if [[ -f .env.vault ]]; then
  export $(grep -v '^#' .env.vault | xargs)
else
  echo "❌ Missing .env.vault file"
  exit 1
fi

# ------------------------------------------------------------------------------
# 🔍 Validate required environment variables
# ------------------------------------------------------------------------------
if [[ -z "$VAULT_ADDR" || -z "$VAULT_TOKEN" || -z "$VAULT_ROLE" ]]; then
  echo "❌ Missing required variables: VAULT_ADDR, VAULT_TOKEN, or VAULT_ROLE"
  exit 1
fi

# ------------------------------------------------------------------------------
# 🛠 Prepare vault working directory and dynamic template
# ------------------------------------------------------------------------------
mkdir -p vault

# Write token to file for Vault Agent authentication
echo "$VAULT_TOKEN" > vault/.vault-token

# Generate Vault template to fetch secrets for the given role
cat > vault/template.tpl <<EOF
{{- with secret "secret/data/$VAULT_ROLE" -}}
{{- range \$key, \$value := .Data.data }}
{{ \$key }}={{ \$value }}
{{- end }}
{{- end }}
EOF

# ------------------------------------------------------------------------------
# 🐳 Pull Vault image if not exists
# ------------------------------------------------------------------------------
if [[ "$(docker images -q hashicorp/vault:latest 2> /dev/null)" == "" ]]; then
  echo "📦 Vault image not found. Pulling from Docker Hub..."
  docker pull hashicorp/vault:latest
fi

# ------------------------------------------------------------------------------
# 🧮 Track run count for log file
# ------------------------------------------------------------------------------
LOG_FILE="vault/render.log"
RUN_COUNT_FILE="vault/.run-count"
RUN_COUNT=1

if [[ -f $RUN_COUNT_FILE ]]; then
  RUN_COUNT=$(( $(cat "$RUN_COUNT_FILE") + 1 ))
fi

echo "$RUN_COUNT" > "$RUN_COUNT_FILE"

# ------------------------------------------------------------------------------
# 🕒 Append header to log file with timestamp + run number
# ------------------------------------------------------------------------------
{
  echo ""
  echo "========================="
  echo "🕒 $(date '+%Y-%m-%d %H:%M:%S')"
  echo "🧪 Vault Render Run #$RUN_COUNT"
  echo "========================="
} >> "$LOG_FILE"

# ------------------------------------------------------------------------------
# 🚀 Start Vault Agent and log output
# ------------------------------------------------------------------------------
docker run --rm \
  --cap-add=IPC_LOCK \
  -v "$PWD:/vault/config" \
  -w /vault/config/vault \
  -e VAULT_ADDR="$VAULT_ADDR" \
  hashicorp/vault:latest \
  agent -config=/vault/config/agent.hcl >> "$LOG_FILE" 2>&1 &

VAULT_PID=$!

# ------------------------------------------------------------------------------
# ⏳ Wait up to 10 seconds for the .env file to be created
# ------------------------------------------------------------------------------
WAIT_SECONDS=10
for ((i=1; i<=WAIT_SECONDS; i++)); do
  if [[ -f vault/.env ]]; then
    mv vault/.env ../.env
    echo "✅ .env successfully rendered and moved"
    kill "$VAULT_PID" >/dev/null 2>&1 || true
    exit 0
  fi
  sleep 1
done

# ------------------------------------------------------------------------------
# ❌ Timeout or error — failed to render .env
# ------------------------------------------------------------------------------
kill "$VAULT_PID" >/dev/null 2>&1 || true
echo "❌ Failed to render .env within expected time"
echo "🪵 See full logs at: vault/render.log"
tail -n 20 vault/render.log || echo "(no log found)"
exit 1