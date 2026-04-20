# CIA — Hybrid Infrastructure Project

Personal reimplementation of the Epitech CIA project, adapted to run locally on macOS (Apple Silicon / ARM) using UTM instead of Proxmox, and Ubuntu + nftables + strongSwan instead of pfSense.

---

## Table of contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Network topology](#network-topology)
- [VM inventory](#vm-inventory)
- [Substitutions from the spec](#substitutions-from-the-spec)
- [Repo layout](#repo-layout)
- [Quick start](#quick-start)
- [Verified working paths](#verified-working-paths)
- [Known limitations](#known-limitations)
- [Roadmap](#roadmap)
- [Documentation index](#documentation-index)

---

## Overview

Two logically separated "sites" connected by an encrypted IPsec site-to-site VPN, with a single hardened bastion host as the external entry point into the remote site. Each site has its own firewall enforcing default-deny policies with stateful packet filtering. An internal website runs on Site B and is reachable from Site A via the tunnel — but not from the simulated public internet.

```
Operator Mac
│
├── SSH (MGMT 192.168.64.0/24) ──► pfw-A ──► pfw-B ──► bastion-B
│                                   │           │           │
│                                   │  IPsec    │           └──► pfw-A (via tunnel)
│                                   │  IKEv2    │
│                                   └───────────┘
│                                        │
│                                  10.255.0.0/24
│                                  (WAN sim)
│
├── Site A LAN (10.10.10.0/24)
│     pfw-A: .1
│     svc-A (future): .20
│     elk-A (future): .30
│
└── Site B LAN (10.20.10.0/24)
      pfw-B: .1
      bastion-B: .10
      app-B: .20
```

---

## Architecture

### VPN tunnel

Site-to-site IPsec using strongSwan (`charon-systemd` daemon, `swanctl` config format).

| Parameter | Value |
|---|---|
| IKE version | IKEv2 |
| Auth | Pre-shared key (lab) |
| IKE proposal | AES_GCM_16_256 / PRF_HMAC_SHA2_384 / ECP_256 |
| ESP proposal | AES_GCM_16_256 / ECP_256 |
| Start action | `trap` (on-demand) |
| DPD action | `restart` |
| Traffic selectors | 10.10.10.0/24 ↔ 10.20.10.0/24 |

Tunnel flow for a packet from Site A to app-B:

```
Site A client
    │
    ▼
pfw-A: matches traffic selector → encrypts with ESP
    │
    ▼  (wan-sim: 10.255.0.0/24)
pfw-B: decrypts, verifies auth
    │
    ▼
app-B (10.20.10.20)
```

### Firewall policy (both pfw-A and pfw-B)

nftables with a default-drop base policy.

| Chain | Default | Accepted traffic |
|---|---|---|
| INPUT | drop | established, ICMP, SSH from MGMT, IKE/ESP from WAN peer |
| FORWARD | drop | LAN↔remote-LAN via tunnel, LAN→MGMT (for NAT internet) |
| NAT (postrouting) | — | masquerade LAN→MGMT for outbound internet |

All drops are logged with rate-limiting (`log prefix "[DROP]" limit rate 5/minute`).

### Bastion host (bastion-B)

Single sanctioned external entry point into Site B.

- Public-key-only SSH (password auth disabled)
- `AllowUsers` whitelist
- `fail2ban` with aggressive ban thresholds
- Modern cipher suite (Ed25519 / ECDH only)
- Short grace time (10 s), forced disconnect after 30 min idle
- Authorization banner on login
- No services other than SSH

### Internal website (app-B)

nginx reverse proxy on port 80, backed by PostgreSQL 16. Reachable only from Site A via the tunnel. No inbound rule on pfw-B allows traffic from the WAN to 10.20.10.20:80 — silently dropped.

---

## Network topology

Three virtual networks, implemented as UTM host-only switches:

| Network | Subnet | Purpose |
|---|---|---|
| `siteA-lan` | 10.10.10.0/24 | Site A internal LAN |
| `siteB-lan` | 10.20.10.0/24 | Site B internal LAN |
| `wan-sim` | 10.255.0.0/24 | Simulated public internet between firewalls |

Plus the **management plane** (UTM Shared Network, `192.168.64.0/24`) — out-of-band operator SSH and outbound internet (apt, DNS) on every VM. See ADR 003.

### Access paths

| Path | How |
|---|---|
| Operator → any VM | SSH via MGMT (192.168.64.0/24) |
| External user → Site B | SSH → bastion-B (via MGMT in lab; WAN address in production) |
| Site A host → app-B | HTTP via tunnel (pfw-A forwards, IPsec encrypts, pfw-B decrypts and routes) |
| bastion-B → Site A | SSH via tunnel (static route on bastion: 10.10.10.0/24 via 10.20.10.1) |

---

## VM inventory

| VM | Site | LAN IP | WAN IP | MGMT IP (DHCP) | Role |
|---|---|---|---|---|---|
| pfw-A | A | 10.10.10.1 | 10.255.0.1 | 192.168.64.26 | Firewall, IPsec peer, NAT |
| pfw-B | B | 10.20.10.1 | 10.255.0.2 | 192.168.64.28 | Firewall, IPsec peer, NAT |
| bastion-B | B | 10.20.10.10 | — | 192.168.64.29 | SSH jump host |
| app-B | B | 10.20.10.20 | — | 192.168.64.30 | nginx + PostgreSQL |

> MGMT IPs are DHCP-assigned by UTM and may change between reboots.

---

## Substitutions from the spec

| Original spec | Used here | Reason |
|---|---|---|
| Proxmox VE | UTM (QEMU/Apple Silicon) | Proxmox has no ARM build; UTM is the ARM-native hypervisor on macOS |
| pfSense | Ubuntu Server 24.04 + nftables | pfSense has no ARM build |
| OpenVPN site-to-site | IPsec IKEv2 (strongSwan) | Team decision; see ADR 004 |

---

## Repo layout

```
.
├── configs/                  # Snapshot of live VM config files (secrets redacted)
│   ├── pfw-A/
│   │   ├── etc/netplan/
│   │   ├── etc/nftables.conf
│   │   └── etc/swanctl/
│   ├── bastion-B/
│   │   ├── etc/netplan/
│   │   └── etc/ssh/
│   └── app-B/
│       ├── etc/netplan/
│       └── var/www/html/
├── docs/
│   ├── architecture/         # Full architecture documentation (this file's detail source)
│   ├── decisions/            # ADRs (Architectural Decision Records)
│   │   ├── 001-arm-substitutes.md
│   │   ├── 002-golden-image.md
│   │   ├── 003-management-plane.md
│   │   ├── 005-bastion-host.md
│   │   └── 006-site-b-static-routes.md
│   ├── runbooks/             # Operational procedures
│   │   ├── ipsec-tunnel.md
│   │   └── bastion-access.md
│   └── NEXT_SESSION.md       # Current pickup point for in-progress work
├── terraform/                # Reserved for future IaC
├── ansible/                  # Reserved for configuration-management migration
├── scripts/                  # Helper scripts
└── isos/                     # Installation media (gitignored)
```

---

## Quick start

### Prerequisites

- macOS on Apple Silicon (M1/M2/M3)
- UTM installed
- Four VMs provisioned from the golden Ubuntu 24.04 ARM64 image (see ADR 002)

### Start the lab

```bash
# 1. Start VMs in UTM
#    Order: pfw-A, pfw-B, bastion-B, app-B

# 2. Verify MGMT reachability (IPs may have shifted after reboot)
ssh ubuntu@192.168.64.26   # pfw-A
ssh ubuntu@192.168.64.28   # pfw-B
ssh ubuntu@192.168.64.29   # bastion-B
ssh ubuntu@192.168.64.30   # app-B

# 3. Bring up the IPsec tunnel (auto-starts on traffic, or manually)
ssh ubuntu@192.168.64.26 "sudo swanctl --initiate --child cia-site-to-site"

# 4. Verify tunnel
ssh ubuntu@192.168.64.26 "sudo swanctl --list-sas"
ssh ubuntu@192.168.64.26 "ping -c3 10.20.10.1"

# 5. Verify end-to-end web path
ssh ubuntu@192.168.64.26 "curl -s http://10.20.10.20"
```

### IPsec quick reference

```bash
# Initiate tunnel
sudo swanctl --initiate --child cia-site-to-site

# Check SAs
sudo swanctl --list-sas

# Terminate tunnel
sudo swanctl --terminate --ike cia-site-to-site

# Full health check — see docs/runbooks/ipsec-tunnel.md
```

### Bastion access

```bash
# From outside (using the bastion's MGMT IP in lab context)
ssh -J ubuntu@192.168.64.29 ubuntu@10.10.10.1   # bastion -> pfw-A via tunnel

# See docs/runbooks/bastion-access.md for full access patterns
```

---

## Verified working paths

As of the last full integration test:

| Path | Method | Status |
|---|---|---|
| Mac → pfw-A (MGMT SSH) | SSH 192.168.64.26 | Pass |
| Mac → pfw-B (MGMT SSH) | SSH 192.168.64.28 | Pass |
| Mac → bastion-B (MGMT SSH, key auth only) | SSH 192.168.64.29 | Pass |
| Mac → app-B (MGMT SSH) | SSH 192.168.64.30 | Pass |
| pfw-A LAN → pfw-B LAN (tunnel) | ping 10.20.10.1 from pfw-A | Pass |
| pfw-A LAN → bastion-B (tunnel) | ping 10.20.10.10 from pfw-A | Pass |
| pfw-A LAN → app-B (tunnel) | ping 10.20.10.20 from pfw-A | Pass |
| bastion-B → pfw-A SSH (via tunnel) | ssh 10.10.10.1 from bastion | Pass |
| bastion-B → app-B HTTP (same LAN) | curl http://10.20.10.20 | Pass |
| Site A → app-B HTTP (via tunnel) | curl http://10.20.10.20 from pfw-A LAN | Pass |
| app-B → Site A return path | rp_filter + static route | Pass |
| WAN → app-B HTTP (should be blocked) | Verified by firewall rule inspection | Pass |

---

## Known limitations

- **VM provisioning is manual** — no Terraform provider exists for UTM; post-provisioning config is destined for Ansible but currently manual.
- **DHCP on MGMT plane** — operator SSH IPs change between VM reboots; verify if SSH fails.
- **PSK stored in local files** — `/etc/swanctl/conf.d/cia-site-to-site.conf` on each pfw and `~/cia-secrets/ipsec-psk.txt` on the Mac. Migration to Vault is the first item in the roadmap.
- **Internet reachability of app-B proven by rule inspection only** — UTM topology does not simulate an actual external probe; "public internet cannot reach app-B" is validated by firewall rule analysis rather than live attack.
- **`strongswan-starter` conflicts** with `charon-systemd` and must be removed (`apt remove strongswan-starter`); only the modern swanctl/charon daemon is used.
- **UTM clone MAC collision** — cloning VMs in UTM does not regenerate MAC addresses by default; enable "Regenerate MAC address on clone" in UTM global preferences, or change MACs manually before boot.
- **Static routes required on Site B non-firewall VMs** — without an explicit route `10.10.10.0/24 via 10.20.10.1`, `rp_filter` silently drops inbound tunnel-originated traffic on bastion-B and app-B (see ADR 006).

---

## Roadmap

In priority order (see `docs/NEXT_SESSION.md` for detail):

1. **svc-A** (10.10.10.20) — Vault + NetBox
   - Vault: initialize, store IPsec PSK, migrate pfw-A and pfw-B to read PSK from Vault at startup
   - NetBox: populate full IP plan via API; serves as the source of truth for addressing

2. **elk-A** (10.10.10.30) — Observability stack
   - Elasticsearch + Logstash + Kibana (4 GB RAM)
   - Syslog forwarding from all VMs
   - Kibana dashboards: firewall drops, SSH auth events, web access logs

3. **DNS forwarding between sites**
   - Unbound on pfw-A and pfw-B
   - Split-horizon: `*.sitea.cia.lab` resolved by pfw-A, `*.siteb.cia.lab` resolved by pfw-B
   - Cross-site forwarding via tunnel

4. **Firewall tightening on pfw-B**
   - Explicit drop rule for WAN → 10.20.10.20:80
   - Live external probe to prove the rule holds

5. **Ansible migration**
   - Roles: `baseline`, `firewall`, `strongswan-peer`, `nginx-app`, `bastion-hardening`
   - Retrofit all manual config into idempotent playbooks
   - Inventory covers all current and planned VMs

---

## Documentation index

### Architecture Decision Records

| ADR | Title | Summary |
|---|---|---|
| [ADR 001](docs/decisions/001-arm-substitutes.md) | ARM-native substitutes | Why UTM + Ubuntu + nftables instead of Proxmox + pfSense |
| [ADR 002](docs/decisions/002-golden-image.md) | Golden image approach | Single base image for all VMs; clone + customize |
| [ADR 003](docs/decisions/003-management-plane.md) | Out-of-band management plane | UTM Shared Network as MGMT; rationale and constraints |
| ADR 004 | IPsec over OpenVPN | Team decision to use strongSwan IKEv2 |
| [ADR 005](docs/decisions/005-bastion-host.md) | Bastion host on Site B | Single external entry point; hardening decisions |
| [ADR 006](docs/decisions/006-site-b-static-routes.md) | Static routes on Site B VMs | Required for rp_filter + tunnel return path |

### Runbooks

| Runbook | Purpose |
|---|---|
| [ipsec-tunnel.md](docs/runbooks/ipsec-tunnel.md) | Health check, initiate, teardown, PSK rotation |
| [bastion-access.md](docs/runbooks/bastion-access.md) | Operator access patterns, hardening verification |

### Full architecture doc

`docs/architecture/readme.md` — detailed description of every component, crypto parameters, firewall policy, addressing plan, stack summary, and verified test matrix.

---

## Stack

| Layer | Tool |
|---|---|
| Hypervisor | UTM (QEMU) — ARM-native on Apple Silicon |
| Base OS | Ubuntu Server 24.04 LTS (ARM64) |
| Firewall | nftables |
| Site-to-site VPN | strongSwan (`charon-systemd`, swanctl) |
| Web server | nginx |
| Database | PostgreSQL 16 |
| SSH hardening | OpenSSH + fail2ban |
| Config capture | Git (secrets redacted) |
| Secrets (current) | Local files, chmod 600 (migrating to Vault) |

---

*Personal educational project — not for production use.*
