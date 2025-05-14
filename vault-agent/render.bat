@echo off
setlocal enabledelayedexpansion

:: ------------------------------------------------------------------------------
:: 📁 Change to script directory
:: ------------------------------------------------------------------------------
cd /d %~dp0

echo 🚀 Starting Vault Agent (one-shot mode) to render .env...

:: ------------------------------------------------------------------------------
:: 📄 Load environment from .env.vault
:: ------------------------------------------------------------------------------
if not exist ".env.vault" (
    echo ❌ Missing .env.vault file
    exit /b 1
)

for /f "tokens=1,* delims==" %%a in ('findstr /v "^#" .env.vault') do (
    set "%%a=%%b"
)

:: ------------------------------------------------------------------------------
:: 🔍 Validate required variables
:: ------------------------------------------------------------------------------
if "%VAULT_ADDR%"=="" (
    echo ❌ Missing VAULT_ADDR
    exit /b 1
)
if "%VAULT_TOKEN%"=="" (
    echo ❌ Missing VAULT_TOKEN
    exit /b 1
)
if "%VAULT_ROLE%"=="" (
    echo ❌ Missing VAULT_ROLE
    exit /b 1
)

:: ------------------------------------------------------------------------------
:: 🛠 Prepare vault directory and dynamic template
:: ------------------------------------------------------------------------------
if not exist vault (
    mkdir vault
)

echo %VAULT_TOKEN%> vault\.vault-token

(
echo {{- with secret "secret/data/%VAULT_ROLE%/env" -}}
echo {{- range $key, $value := .Data.data }}
echo {{ $key }}={{ $value }}
echo {{- end }}
echo {{- end }}
) > vault\template.tpl

:: ------------------------------------------------------------------------------
:: 🚀 Start Vault Agent in background (quiet mode)
:: ------------------------------------------------------------------------------
start "" /b cmd /c ^
docker run --rm ^
  --cap-add=IPC_LOCK ^
  -v "%cd%:/vault/config" ^
  -w /vault/config/vault ^
  -e VAULT_ADDR="%VAULT_ADDR%" ^
  hashicorp/vault:latest ^
  agent -config=/vault/config/agent.hcl >nul 2>&1

:: ------------------------------------------------------------------------------
:: ⏳ Wait for .env to be created (max 3 seconds)
:: ------------------------------------------------------------------------------
set tries=0
:wait_loop
set /a tries+=1
if exist vault\.env (
    move /Y vault\.env ..\.env >nul
    echo ✅ .env successfully rendered and moved
    exit /b 0
)
if %tries% GEQ 3 (
    echo ❌ Failed to render .env within expected time
    exit /b 1
)
timeout /t 1 >nul
goto wait_loop