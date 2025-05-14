# 🔐 Vault Agent .env Renderer

ระบบนี้ช่วยให้คุณสามารถ **ดึง secrets จาก HashiCorp Vault** มาแปลงเป็นไฟล์ `.env` ได้อย่างอัตโนมัติ  
โดยรองรับการใช้งานแบบ dynamic เช่นกำหนด `server`, `role`, และ `token` ได้ง่าย ๆ ผ่าน `.env.vault`

---

## 📦 Features

- ✅ Render secrets จาก Vault KV (v2) เป็น `.env`
- ✅ รองรับหลาย role (เช่น `frontend`, `backend`)
- ✅ Dynamic Vault server address (`VAULT_ADDR`)
- ✅ ใช้ static `agent.hcl` + dynamic ENV
- ✅ ใช้งานได้ทั้งใน CI/CD และ local dev
- ✅ รองรับทั้ง `render.sh` (Linux/macOS) และ `render.bat` (Windows)

---

## 🚀 Server-Side Setup (ครั้งเดียว)

### 1. Start Vault Server

````bash
docker compose -f docker-compose.server.yml up -d
````

### 2. เข้าไปใน Container

````bash
docker exec -it vault sh
````

### 3. กำหนด Secrets

````bash
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root-token'

vault kv put secret/frontend/env API_URL=http://frontend.com API_KEY=frontend-key
vault kv put secret/backend/env DB_URL=postgres://db BACKEND_KEY=super-secret
````

### 4. สร้าง Policy สำหรับแต่ละ Role

#### ➤ frontend-readonly.hcl

````hcl
cat > frontend-readonly.hcl <<EOF
path "secret/data/frontend/*" {
  capabilities = ["read", "list"]
}
EOF
````

#### ➤ backend-readonly.hcl

````hcl
cat > backend-readonly.hcl <<EOF
path "secret/data/backend/*" {
  capabilities = ["read", "list"]
}
EOF
````

#### ➤ Apply Policies

````bash
vault policy write frontend-readonly frontend-readonly.hcl
vault policy write backend-readonly backend-readonly.hcl
````

### 5. สร้าง Token ตาม Role

````bash
vault token create -policy="frontend-readonly" -orphan -period=768h -display-name="frontend"
vault token create -policy="backend-readonly" -orphan -period=768h -display-name="backend"
````

> 📌 คัดลอก token ที่ได้ไว้ใช้งานฝั่ง Agent

````bash
exit
````

---

## 💻 Agent-Side Usage

### 1. เตรียม `.env.vault`

```bash
cp vault-agent/.env.vault.example vault-agent/.env.vault
```

จากนั้นแก้ไขไฟล์ `.env.vault` ให้ใส่ค่า token และ server ของคุณ เช่น:

````env
VAULT_ADDR=http://<your-server>:8200
VAULT_TOKEN=hvs.xxxxxxxxxxxxxxxxx
VAULT_ROLE=frontend
````

> ✨ เปลี่ยน `VAULT_ROLE` เป็น `backend` ถ้าต้องการ pull จาก backend

---

### 2. Run Script

#### บน Linux / macOS

````bash
./vault-agent/render.sh
````

#### บน Windows

````cmd
vault-agent\render.bat
````

ระบบจะ:
- สร้างไฟล์ `.vault-token` และ `template.tpl`
- เรียก `Vault Agent` เพื่อดึง secrets
- แปลงผลลัพธ์เป็นไฟล์ `.env`

---

## 📁 Project Structure

```
.
├── docker-compose.server.yml
├── README.md
└── vault-agent/
    ├── .env.vault              # สำหรับใช้จริง (ignore ด้วย .gitignore)
    ├── .env.vault.example      # ตัวอย่างไฟล์ config
    ├── agent.hcl               # Vault Agent config (ใช้ ${VAULT_ADDR})
    ├── render.sh               # สคริปต์สำหรับ Linux/macOS
    └── render.bat              # สคริปต์สำหรับ Windows
```

---

## ✅ ตัวอย่าง Output

เมื่อ `VAULT_ROLE=frontend`:

````env
API_URL=http://frontend.com
API_KEY=frontend-key
````

หรือ `VAULT_ROLE=backend`:

````env
DB_URL=postgres://db
BACKEND_KEY=super-secret
````

---
