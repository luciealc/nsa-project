# Next session — pick up here

## Status: Firewalls + IPsec + Bastion all working ✅

End-to-end admin flow proven: Mac -> bastion-B -> pfw-A via tunnel.

## Current VM state (MGMT IPs shift with DHCP, verify on boot)

| VM | LAN IP | Role |
|---|---|---|
| pfw-A | 10.10.10.1 (LAN), 10.255.0.1 (WAN) | Site A firewall + IPsec peer |
| pfw-B | 10.20.10.1 (LAN), 10.255.0.2 (WAN) | Site B firewall + IPsec peer |
| bastion-B | 10.20.10.10 (LAN) | SSH entry point to Site B |

All on Shared Network (UTM) for MGMT.

## Tunnel
- IKEv2, AES-GCM-256, ECP-256, SHA2-384
- Traffic selectors 10.10.10.0/24 <-> 10.20.10.0/24
- On-demand (trap), DPD restart on failure

## Next steps in priority

1. **app-B (Site B app + DB + internal website)** — 10.20.10.20
   - Nginx + static or minimal dynamic site
   - Accessible from Site A users only (firewall-enforced)
   - Satisfies spec's "internal website" deliverable

2. **svc-A (Site A services: NetBox + Vault)** — 10.10.10.20
   - Vault to hold the IPsec PSK (migrate from local file)
   - NetBox as the IP-plan source of truth

3. **elk-A (Site A observability)** — 10.10.10.30
   - Heaviest VM (~4 GB); Elasticsearch, Kibana, Logstash
   - Ship pfw-A, pfw-B, bastion-B, all-VM syslog here

4. **DNS forwarding**
   - Unbound on pfw-A and pfw-B, forwarding *.siteb.cia.lab <-> *.sitea.cia.lab

5. **Ansible**
   - Inventory, roles, retrofit all manual config to idempotent playbooks

## Quick start next session

```bash
# Bring the lab up
# In UTM, start (in order): pfw-A, pfw-B, bastion-B
# Then from Mac:
ssh cia@<pfw-A-mgmt-ip>
sudo swanctl --list-sas           # should show tunnel up after first packet
```

If tunnel doesn't auto-establish, trigger it:

```bash
# From pfw-A
sudo swanctl --initiate --child lan-to-lan
```
