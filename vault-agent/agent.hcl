pid_file = "/tmp/vault-agent.pid"
exit_after_auth = true

auto_auth {
  method "token_file" {
    config {
      token_file_path = "/vault/config/vault/.vault-token"
    }
  }

  sink "file" {
    config {
      path = "/vault/config/vault/.env"
      mode = 0644
    }
  }
}

vault {
  address = "${VAULT_ADDR}"
}

template {
  source      = "/vault/config/vault/template.tpl"
  destination = "/vault/config/vault/.env"
  wait {
    min = "0s"
    max = "1s"
  }
}
