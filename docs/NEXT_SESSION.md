# Next session — pick up here

## Status: Core infrastructure + internal website working

Foundation is solid. Every path tested in an integration run passed.

## Current VMs

| VM | LAN IP | MGMT IP (DHCP) | Role |
|---|---|---|---|
| pfw-A | 10.10.10.1 / 10.255.0.1 | 192.168.64.26 | Firewall + IPsec peer |
| pfw-B | 10.20.10.1 / 10.255.0.2 | 192.168.64.28 | Firewall + IPsec peer |
| bastion-B | 10.20.10.10 | 192.168.64.29 | SSH jump host |
| app-B | 10.20.10.20 | 192.168.64.30 | nginx + PostgreSQL |

MGMT IPs may shift between reboots; verify if SSH fails.

## Proven working

- Mac -> each VM via MGMT SSH
- pfw-A <-> pfw-B IPsec tunnel (IKEv2, AES-GCM-256)
- pfw-A LAN -> all Site B LAN hosts via tunnel
- bastion -> pfw-A SSH (via tunnel)
- Site A LAN -> app-B HTTP (via tunnel)

## Next steps, priority order

1. svc-A (Site A services: NetBox + Vault) — 10.10.10.20
   - Clone golden, attach to siteA-lan + Shared
   - Install Vault (single-node lab config)
   - Install NetBox (PostgreSQL, Redis, nginx, gunicorn)
   - Initialize Vault, store the IPsec PSK as a secret
   - Populate NetBox with the IP plan via its API
   - Add static route: 10.20.10.0/24 via 10.10.10.1

2. elk-A (Site A observability) — 10.10.10.30
   - 4 GB RAM allocation
   - Elasticsearch, Kibana, Logstash
   - Forward pfw-A, pfw-B, bastion-B, app-B syslog to Logstash
   - Basic Kibana dashboards: firewall drops, SSH auth, web access

3. DNS forwarding between sites (per spec)
   - Unbound on pfw-A and pfw-B
   - pfw-A resolves *.siteb.cia.lab via pfw-B (and vice versa)
   - Each pfw serves DNS to its own LAN

4. Tighten firewall rules on pfw-B
   - Explicit drop of inbound WAN traffic targeting 10.20.10.20:80
   - Documented proof that the internet cannot reach app-B

5. Ansible migration
   - Inventory with all VMs
   - Roles: baseline, firewall, strongswan-peer, nginx-app, bastion-hardening
   - Retrofit existing manual config into idempotent playbooks

## Known gotchas for pickup

- UTM cloning doesn't regenerate MACs by default; manual change required
- strongswan-starter conflicts with charon-systemd; remove it
- swanctl .secrets files aren't auto-included; inline secrets into .conf
- Site B VMs need explicit static route 10.10.10.0/24 via 10.20.10.1 or
  rp_filter silently drops inbound tunnel traffic (ADR 006)
- MGMT plane IPs shift on DHCP renewal

## PSK

Still in `~/cia-secrets/ipsec-psk.txt` on the Mac and inline in each pfw's
`/etc/swanctl/conf.d/cia-site-to-site.conf`. Redacted in committed configs.
Migration to Vault is step 1 of next session.
