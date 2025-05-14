@echo off
setlocal enabledelayedexpansion

echo 🚀 เริ่มรัน Vault Agent (one-shot mode) เพื่อ render .env...

REM ✅ โหลด ENV จาก .env.vault
if not exist ".env.vault" (
    echo ❌ ไม่พบไฟล์ .env.vault
    exit /b 1
)

REM ✅ ดึงค่าจาก .env.vault
for /f "tokens=1,* delims==" %%a in ('findstr /v "^#" .env.vault') do (
    set "%%a=%%b"
)

REM ✅ ตรวจสอบตัวแปรจำเป็น
if "%VAULT_ADDR%"=="" (
    echo ❌ ต้องกำหนด VAULT_ADDR ใน .env.vault
    exit /b 1
)
if "%VAULT_TOKEN%"=="" (
    echo ❌ ต้องกำหนด VAULT_TOKEN ใน .env.vault
    exit /b 1
)
if "%VAULT_ROLE%"=="" (
    echo ❌ ต้องกำหนด VAULT_ROLE ใน .env.vault
    exit /b 1
)

REM ✅ สร้างโฟลเดอร์ vault ถ้ายังไม่มี
if not exist vault (
    mkdir vault
)

REM ✅ สร้าง .vault-token
echo %VAULT_TOKEN%> vault\.vault-token

REM ✅ สร้าง template.tpl แบบ dynamic
(
echo {{- with secret "secret/data/%VAULT_ROLE%/env" -}}
echo {{- range $key, $value := .Data.data }}
echo {{ $key }}={{ $value }}
echo {{- end }}
echo {{- end }}
) > vault\template.tpl

REM ✅ รัน Vault Agent
docker run --rm ^
  --cap-add=IPC_LOCK ^
  -v "%cd%:/vault/config" ^
  -w /vault/config/vault ^
  -e VAULT_ADDR="%VAULT_ADDR%" ^
  hashicorp/vault:latest ^
  agent -config=/vault/config/agent.hcl

REM ✅ ตรวจสอบผลลัพธ์
if exist vault\.env (
    move /Y vault\.env .env >nul
    echo ✅ .env สร้างและย้ายสำเร็จ
) else (
    echo ❌ ไม่พบ vault\.env กรุณาตรวจสอบ log ข้างต้น
    exit /b 1
)