# CIA project — Vault server config (lab)

ui = true

storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "http://10.10.10.20:8200"
cluster_addr = "https://10.10.10.20:8201"

disable_mlock = true
