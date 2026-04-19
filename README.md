# CIA — Hybrid Infrastructure Project

Personal reimplementation of the Epitech CIA project, adapted to run locally
on macOS (Apple Silicon / ARM) using UTM instead of Proxmox, and Ubuntu +
nftables + strongSwan instead of pfSense.

## Status

Working foundation:

- Two firewalls (pfw-A on Site A, pfw-B on Site B)
- IPsec site-to-site VPN between the two sites (IKEv2, AES-GCM-256)
- Hardened bastion host on Site B
- Internal website on Site B, reachable from Site A via tunnel
- End-to-end admin access: Mac -> bastion -> tunnel -> Site A

See `docs/architecture/README.md` for full architecture documentation and
diagrams.

## Substitutions from the original spec

| Original | Used here | Reason |
|---|---|---|
| Proxmox VE | UTM | ARM-native on Apple Silicon |
| pfSense | Ubuntu + nftables + strongSwan | pfSense has no ARM build |
| OpenVPN site-to-site | IPsec (strongSwan) | Team decision, documented in ADR 004 |

## Repo layout

- `docs/architecture/` — architecture diagrams and explanation
- `docs/decisions/` — ADRs (architectural decision records)
- `docs/runbooks/` — operational procedures
- `docs/NEXT_SESSION.md` — current pickup point for work in progress
- `configs/` — snapshot of live VM config files (secrets redacted)
- `terraform/` — reserved for future IaC
- `ansible/` — reserved for upcoming configuration-management migration
- `scripts/` — helper scripts
- `isos/` — installation media (gitignored)

## Addressing plan

| Zone | Range | Current state |
|---|---|---|
| Site A LAN | 10.10.10.0/24 | pfw-A, future svc-A, elk-A |
| Site B LAN | 10.20.10.0/24 | pfw-B, bastion-B, app-B |
| Inter-site WAN | 10.255.0.0/24 | pfw-A, pfw-B (wan-sim) |
| Operator MGMT | 192.168.64.0/24 | All VMs (UTM Shared Network) |

## Quick start (pickup)

1. Start VMs in UTM: pfw-A, pfw-B, bastion-B, app-B
2. SSH into pfw-A via its MGMT IP
3. Trigger the IPsec tunnel with a LAN-to-LAN ping or `swanctl --initiate`
4. See `docs/NEXT_SESSION.md` for current work

## License / ownership

Personal educational project, not for production use.
