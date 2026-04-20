# Next session — pick up here

## Status: Vault + NetBox live, IPAM populated

svc-A is running both Vault (secrets) and NetBox (IPAM). The full IP plan
and device inventory are now stored in NetBox as the source of truth.

## VM inventory

| VM | LAN IP | MGMT IP | Role |
|---|---|---|---|
| pfw-A | 10.10.10.1 / 10.255.0.1 | 192.168.64.26 | Firewall + IPsec peer |
| pfw-B | 10.20.10.1 / 10.255.0.2 | 192.168.64.28 | Firewall + IPsec peer |
| bastion-B | 10.20.10.10 | 192.168.64.29 | SSH jump host |
| app-B | 10.20.10.20 | 192.168.64.30 | nginx + internal website |
| svc-A | 10.10.10.20 | 192.168.64.29 | Vault + NetBox |

(Note: MGMT IPs may have shifted; verify on boot)

## What's in Vault (at path `cia/`)

- `cia/ipsec/site-to-site` — IPsec PSK
- `cia/netbox/db` — DB creds
- `cia/netbox/app` — Django SECRET_KEY
- `cia/netbox/admin` — admin password
- `cia/netbox/pepper` — API token pepper
- `cia/netbox/api` — current API token (v2 format: `nbt_<key>.<plaintext>`)

## What's in NetBox (populated via scripts/populate_netbox.sh)

- 2 sites (Site A, Site B)
- 4 prefixes (siteA-lan, siteB-lan, wan-sim, mgmt)
- 4 device roles (Firewall, Bastion, App Server, Services)
- 5 devices (pfw-A, pfw-B, bastion-B, app-B, svc-A)
- 7 IP addresses

## Access NetBox UI

SSH tunnel from Mac:

    ssh -L 8080:10.10.10.20:80 cia@<svc-A-mgmt-ip>

Then browser: http://localhost:8080
Credentials: admin / stored in Vault at cia/netbox/admin

## Vault unseal after reboot

Vault seals on reboot — this is by design. To unseal:

    ssh cia@<svc-A-mgmt-ip>
    export VAULT_ADDR='http://127.0.0.1:8200'
    vault operator unseal   # repeat 3 times, different keys each time

Unseal keys in ~/cia-secrets/vault-init.txt on operator Mac.

## Next steps, priority order

1. **elk-A (Site A observability)** — 10.10.10.30
   - Elasticsearch + Kibana + Logstash on its own VM (4 GB RAM)
   - Forward syslog from pfw-A, pfw-B, bastion-B, app-B, svc-A
   - Basic Kibana dashboards: firewall drops, SSH auth, HTTP access

2. **DNS forwarding between sites** (per spec)
   - Unbound on pfw-A and pfw-B
   - pfw-A resolves *.siteb.cia.lab via pfw-B (and vice versa)

3. **Migrate IPsec PSK retrieval to Vault**
   - pfw-A/pfw-B currently have the PSK inlined in /etc/swanctl/conf.d/*.conf
   - Target: Ansible task that retrieves from Vault at deploy time

4. **Ansible migration**
   - Inventory with all VMs
   - Roles: baseline, firewall, strongswan-peer, nginx-app, bastion, netbox-client, vault-client

5. **Tighten pfw-A firewall for svc-A access from Site B**
   - Currently no Site B host can reach Vault or NetBox on svc-A
   - Add rules for known bastion/app IPs if needed for Ansible

## Known gotchas

- NetBox 4.3+ requires API_TOKEN_PEPPERS as a dict `{0: 'long_string_>=50_chars'}`
- NetBox v2 tokens use `Bearer nbt_<key>.<plaintext>` — NOT `Token`
- Vault CLI needs VAULT_ADDR=http://127.0.0.1:8200 (export in ~/.bashrc on svc-A)
- strongswan-starter package conflicts with charon-systemd; always remove it
- Site B VMs need static route `10.10.10.0/24 via 10.20.10.1` (ADR 006)
- MGMT plane IPs shift on DHCP renewal between boots
