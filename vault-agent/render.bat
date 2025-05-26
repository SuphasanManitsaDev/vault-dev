@echo off
setlocal EnableDelayedExpansion

REM ------------------------------------------------------------------------------
REM 📁 Change directory to the location of this script
REM ------------------------------------------------------------------------------
cd /d "%~dp0"

echo 🚀 Starting Vault Agent (one-shot mode) to render .env...

REM ------------------------------------------------------------------------------
REM 📄 Load and export variables from .env.vault
REM ------------------------------------------------------------------------------
if not exist .env.vault (
  echo ❌ Missing .env.vault file
  exit /b 1
)

for /f "usebackq tokens=* delims=" %%a in (".env.vault") do (
  set "line=%%a"
  echo !line! | findstr /b /v "#" >nul
  if not errorlevel 1 (
    for /f "tokens=1,2 delims==" %%k in ("!line!") do (
      set "%%k=%%l"
    )
  )
)

REM ------------------------------------------------------------------------------
REM 🔍 Validate required environment variables
REM ------------------------------------------------------------------------------
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

REM ------------------------------------------------------------------------------
REM 🛠 Prepare vault working directory and dynamic template
REM ------------------------------------------------------------------------------
mkdir vault 2>nul

REM Write token to file
echo %VAULT_TOKEN% > vault\.vault-token

REM Write Vault template
(
echo {{- with secret "secret/data/%VAULT_ROLE%" -}}
echo {{- range $key, $value := .Data.data }}
echo {{$key}}={{$value}}
echo {{- end }}
echo {{- end }}
) > vault\template.tpl

REM ------------------------------------------------------------------------------
REM 🐳 Pull Vault image if not present
REM ------------------------------------------------------------------------------
docker image inspect hashicorp/vault:latest >nul 2>&1
if errorlevel 1 (
  echo 📦 Vault image not found. Pulling from Docker Hub...
  docker pull hashicorp/vault:latest
)

REM ------------------------------------------------------------------------------
REM 🧮 Run count
REM ------------------------------------------------------------------------------
set "LOG_FILE=vault\render.log"
set "RUN_COUNT_FILE=vault\.run-count"
set RUN_COUNT=1

if exist %RUN_COUNT_FILE% (
  set /p RUN_COUNT=<%RUN_COUNT_FILE%
  set /a RUN_COUNT+=1
)
echo %RUN_COUNT% > %RUN_COUNT_FILE%

REM ------------------------------------------------------------------------------
REM 🕒 Append log header
REM ------------------------------------------------------------------------------
echo. >> %LOG_FILE%
echo ========================= >> %LOG_FILE%
for /f %%t in ('powershell -Command "Get-Date -Format \"yyyy-MM-dd HH:mm:ss\" "') do set TIME_STRING=%%t
echo 🕒 %TIME_STRING% >> %LOG_FILE%
echo 🧪 Vault Render Run #%RUN_COUNT% >> %LOG_FILE%
echo ========================= >> %LOG_FILE%

REM ------------------------------------------------------------------------------
REM 🚀 Start Vault Agent and render
REM ------------------------------------------------------------------------------
start /b "" cmd /c docker run --rm ^
  --cap-add=IPC_LOCK ^
  -v "%cd%:/vault/config" ^
  -w /vault/config/vault ^
  -e VAULT_ADDR=%VAULT_ADDR% ^
  hashicorp/vault:latest ^
  agent -config=/vault/config/agent.hcl >> %LOG_FILE% 2>&1

REM ------------------------------------------------------------------------------
REM ⏳ Wait up to 10 seconds for vault\.env
REM ------------------------------------------------------------------------------
set WAIT_SECONDS=10
set FOUND_ENV=0

for /l %%i in (1,1,%WAIT_SECONDS%) do (
  if exist vault\.env (
    move /y vault\.env ..\.env >nul
    echo ✅ .env successfully rendered and moved
    set FOUND_ENV=1
    goto :DONE
  )
  timeout /t 1 >nul
)

:DONE

REM ------------------------------------------------------------------------------
REM ❌ Fallback if not found
REM ------------------------------------------------------------------------------
if "%FOUND_ENV%"=="0" (
  echo ❌ Failed to render .env within expected time
  echo 🪵 See full logs at: vault\render.log
  powershell -Command "Get-Content -Tail 20 'vault/render.log'" || echo (no log found)
  exit /b 1
)

endlocal
exit /b 0