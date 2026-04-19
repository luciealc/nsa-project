# CIA — Hybrid Infrastructure Project

Personal reimplementation of the Epitech CIA project, adapted to run locally
on macOS (Apple Silicon / ARM) using UTM instead of Proxmox, and Ubuntu +
nftables + strongSwan instead of pfSense.

## Architecture

Two simulated sites connected by an IPsec site-to-site VPN, each with a
firewall VM and a handful of service VMs, plus centralized IPAM (NetBox),
log aggregation (Elastic), and secret management (Vault).

See `docs/architecture/` for diagrams and `docs/decisions/` for architectural
decisions.

## Addressing plan

| Zone | Site A | Site B |
|---|---|---|
| Management | 10.10.10.0/24 | 10.20.10.0/24 |
| Services | 10.10.20.0/24 | 10.20.30.0/24 |
| Monitoring | 10.10.50.0/24 | — |
| DMZ/Bastion | — | 10.20.40.0/24 |
| Simulated WAN | 10.255.0.0/24 | 10.255.0.0/24 |
| Operator MGMT plane | 192.168.64.0/24 (UTM Shared Network) | same |

## Substitutions from the original spec

| Original | Used here | Reason |
|---|---|---|
| Proxmox VE | UTM | ARM-native on Apple Silicon |
| pfSense | Ubuntu + nftables + strongSwan | pfSense has no ARM build |
| OpenVPN site-to-site | IPsec (strongSwan) | Team decision, predates ARM constraint |

## Repo layout

- `docs/` — architecture notes, runbooks, ADRs
- `configs/` — snapshot of live VM config files (version-controlled mirror)
- `terraform/` — IaC (where UTM permits)
- `ansible/` — configuration management (will grow to become the primary
  automation layer)
- `scripts/` — helper scripts
- `isos/` — installation media (gitignored)

## Status

Work in progress. See `docs/NEXT_SESSION.md` for the current pickup point.
