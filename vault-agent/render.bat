@echo off
setlocal enabledelayedexpansion

:: ------------------------------------------------------------------------------
:: 📁 Set working directory to the location of this script
:: ------------------------------------------------------------------------------
cd /d "%~dp0"

echo 🚀 Starting Vault Agent (one-shot mode) to render .env...

:: ------------------------------------------------------------------------------
:: 📄 Load and export variables from .env.vault
:: ------------------------------------------------------------------------------
if not exist .env.vault (
  echo ❌ Missing .env.vault file
  exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%A in (`findstr /V "^#" .env.vault`) do (
  set "%%A=%%B"
)

:: ------------------------------------------------------------------------------
:: 🔍 Validate required environment variables
:: ------------------------------------------------------------------------------
if not defined VAULT_ADDR (
  echo ❌ Missing VAULT_ADDR
  exit /b 1
)
if not defined VAULT_TOKEN (
  echo ❌ Missing VAULT_TOKEN
  exit /b 1
)
if not defined VAULT_ROLE (
  echo ❌ Missing VAULT_ROLE
  exit /b 1
)

:: ------------------------------------------------------------------------------
:: 🛠 Prepare vault working directory and dynamic template
:: ------------------------------------------------------------------------------
if not exist vault (
  mkdir vault
)

:: Write token to file
echo %VAULT_TOKEN% > vault\.vault-token

:: Generate Vault template
(
echo {{- with secret "secret/data/%VAULT_ROLE%" -}}
echo {{- range $key, $value := .Data.data }}
echo {{$key}}={{$value}}
echo {{- end }}
echo {{- end }}
) > vault\template.tpl

:: ------------------------------------------------------------------------------
:: 🚀 Start Vault Agent and render secrets
:: ------------------------------------------------------------------------------
start /b /wait docker run --rm ^
  --cap-add=IPC_LOCK ^
  -v "%cd%:/vault/config" ^
  -w /vault/config/vault ^
  -e VAULT_ADDR="%VAULT_ADDR%" ^
  hashicorp/vault:latest ^
  agent -config=/vault/config/agent.hcl > nul 2>&1

:: ------------------------------------------------------------------------------
:: ⏳ Wait up to 3 seconds for the .env file to be created
:: ------------------------------------------------------------------------------
set FOUND_ENV=0
for %%i in (1 2 3) do (
  if exist vault\.env (
    move /Y vault\.env ..\.env > nul
    echo ✅ .env successfully rendered and moved
    set FOUND_ENV=1
    goto :EOF
  )
  timeout /t 1 > nul
)

:: ------------------------------------------------------------------------------
:: ❌ Timeout or error — failed to render .env
:: ------------------------------------------------------------------------------
echo ❌ Failed to render .env within expected time
echo 🪵 See full logs at: vault\render.log
type vault\render.log | more +%lines% > nul
exit /b 1