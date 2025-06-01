# 🔐 Vault Agent .env Renderer

This tool allows you to **securely fetch secrets from HashiCorp Vault** and render them into a local `.env` file.  
It supports dynamic environments with flexible configuration via `.env.vault`.

---

## 📦 Features

- ✅ Render secrets from Vault KV (v2) into `.env`
- ✅ Supports multiple roles (e.g., `frontend`, `backend`)
- ✅ Dynamic Vault server address (`VAULT_ADDR`)
- ✅ Static `agent.hcl` + dynamic runtime configuration
- ✅ Works in local dev and CI/CD environments
- ✅ Cross-platform support for `render.sh` (Linux/macOS) and `render.bat` (Windows)

---

## 🚀 Server Setup (One-Time)

### 1. Start Vault Server

```bash
docker compose -f docker-compose.server.yml up -d
```

### 2. Access Vault Container

```bash
docker exec -it vault sh
```

### 3. Define Secrets

```bash
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root-token'

vault kv put secret/frontend API_URL=http://frontend.com API_KEY=frontend-key
vault kv put secret/backend DB_URL=postgres://db BACKEND_KEY=super-secret
vault kv put secret/mobile API_URL=http://example.com
```

### 4. Create Policies

#### `frontend-readonly.hcl`

```bash
echo 'path "secret/data/frontend" {
  capabilities = ["read", "list"]
}' > frontend-readonly.hcl
```

#### `backend-readonly.hcl`

```bash
echo 'path "secret/data/backend" {
  capabilities = ["read", "list"]
}' > backend-readonly.hcl
```

#### `mobile-readonly.hcl`

```bash
echo 'path "secret/data/mobile" {
  capabilities = ["read", "list"]
}' > mobile-readonly.hcl
```

Apply the policies:

```bash
vault policy write frontend-readonly frontend-readonly.hcl
vault policy write backend-readonly backend-readonly.hcl
vault policy write mobile-readonly mobile-readonly.hcl
```

### 5. Generate Tokens

```bash
vault token create -policy="frontend-readonly" -orphan -ttl=0 -display-name="frontend"
vault token create -policy="backend-readonly" -orphan -ttl=0 -display-name="backend"
vault token create -policy="mobile-readonly" -orphan -ttl=0 -display-name="mobile"
```

> 📌 Copy the generated token for Agent usage

หรือใช้ UI ก็ได้ ไปที่ Tools > API Explorer แล้วเลือก POST /auth/token/create
```json
{
  "policies": ["frontend-readonly"],
  "no_parent": true,
  "ttl": "0",
  "display_name": "frontend"
}
```


```bash
exit
```

---

## 💻 Agent Usage

Clone the renderer and set up:

```bash
git clone https://github.com/SuphasanManitsaDev/vault-dev.git
mv vault-dev/vault-agent ./
rm -rf vault-dev
```

### 1. Create `.env.vault`

```bash
cp vault-agent/.env.vault.example vault-agent/.env.vault
```

Edit `vault-agent/.env.vault`:

```env
VAULT_ADDR=http://<your-server>:8200
VAULT_TOKEN=hvs.xxxxxxxxxxxxxxxxx
VAULT_ROLE=frontend
```

> ✨ Change `VAULT_ROLE` to `backend` to fetch backend secrets

---

### 2. Run Renderer

#### Linux/macOS:

```bash
./vault-agent/render.sh
```

#### Windows:

```cmd
vault-agent\render.bat
```

What it does:
- Creates `.vault-token` and `template.tpl`
- Runs Vault Agent to fetch and render secrets
- Outputs to `.env` in the root directory

---

## 📁 Folder Structure

```
.
├── docker-compose.server.yml
├── README.md
└── vault-agent/
    ├── .env.vault              # Actual config (ignored by Git)
    ├── .env.vault.example      # Example config for setup
    ├── agent.hcl               # Vault Agent configuration file
    ├── render.sh               # Linux/macOS rendering script
    └── render.bat              # Windows rendering script
```

---

## ✅ Example Output

When `VAULT_ROLE=frontend`:

```env
API_URL=http://frontend.com
API_KEY=frontend-key
```

When `VAULT_ROLE=backend`:

```env
DB_URL=postgres://db
BACKEND_KEY=super-secret
```

---

## 🧠 Pro Tips

- Extend the script to support multiple roles
- Merge `.env` with `.env.local`
- Integrate in CI pipelines (GitHub Actions, GitLab CI, etc.)

---

## 📄 License

MIT © [Your Name]
