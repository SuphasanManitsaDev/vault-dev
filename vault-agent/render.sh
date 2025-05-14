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
{{- with secret "secret/data/$VAULT_ROLE/env" -}}
{{- range \$key, \$value := .Data.data }}
{{ \$key }}={{ \$value }}
{{- end }}
{{- end }}
EOF

# ------------------------------------------------------------------------------
# 🚀 Start Vault Agent in background and render secrets
# ------------------------------------------------------------------------------
docker run --rm \
  --cap-add=IPC_LOCK \
  -v "$PWD:/vault/config" \
  -w /vault/config/vault \
  -e VAULT_ADDR="$VAULT_ADDR" \
  hashicorp/vault:latest \
  agent -config=/vault/config/agent.hcl > vault/render.log 2>&1 &

VAULT_PID=$!

# ------------------------------------------------------------------------------
# ⏳ Wait up to 3 seconds for the .env file to be created
# ------------------------------------------------------------------------------
for i in {1..3}; do
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
tail -n 1 vault/render.log
exit 1