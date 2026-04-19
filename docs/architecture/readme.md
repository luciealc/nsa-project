# CIA — Architecture Documentation

This document describes the current state of the hybrid infrastructure as implemented locally on macOS (Apple Silicon) using UTM. It reflects what is actually built and tested, not the target/aspirational architecture.

## High-level overview

Two logically separated "sites" connected by an encrypted IPsec site-to-site VPN, with a single hardened bastion host as the external entry point into the remote site. Each site has its own firewall enforcing default-deny policies with stateful filtering. An internal website runs on Site B and is reachable from Site A via the tunnel, but not from the public internet.

```mermaidflowchart LR
subgraph SiteA["Site A (on-prem)"]
pfwA["pfw-A<br/>10.10.10.1<br/>Firewall + IPsec"]
futureA["svc-A, elk-A<br/>(future)"]
endsubgraph SiteB["Site B (remote)"]
    pfwB["pfw-B<br/>10.20.10.1<br/>Firewall + IPsec"]
    bastion["bastion-B<br/>10.20.10.10<br/>SSH jump host"]
    app["app-B<br/>10.20.10.20<br/>nginx + PostgreSQL"]
endMac["Operator Mac<br/>MGMT plane"]pfwA <-->|"IPsec IKEv2"| pfwB
Mac -.->|SSH via MGMT| pfwA
Mac -.->|SSH via MGMT| pfwB
Mac -.->|SSH via MGMT| bastion
Mac -.->|SSH via MGMT| appbastion -->|SSH via tunnel| pfwA
futureA -.->|HTTP via tunnel| app

## Network topology

Three logical network segments, implemented as UTM host-only virtual switches:

| Network | Range | Purpose |
|---|---|---|
| `siteA-lan` | 10.10.10.0/24 | Site A internal LAN |
| `siteB-lan` | 10.20.10.0/24 | Site B internal LAN |
| `wan-sim` | 10.255.0.0/24 | Simulated public internet between firewalls |

A separate **management plane** — UTM's built-in Shared Network on `192.168.64.0/24` — is used for operator SSH access and outbound internet (apt, DNS) on every VM.

## VPN tunnel

Site-to-site IPsec VPN using strongSwan (charon-systemd daemon, swanctl config format).

**Crypto parameters:**
- IKEv2 with pre-shared key authentication (lab; certs for production)
- IKE proposal: AES_GCM_16_256 / PRF_HMAC_SHA2_384 / ECP_256
- ESP proposal: AES_GCM_16_256 / ECP_256
- `start_action = trap` — tunnel establishes on demand
- `dpd_action = restart` — auto-restart on peer failure
- Traffic selectors: 10.10.10.0/24 ↔ 10.20.10.0/24

```mermaidsequenceDiagram
participant LanA as Site A client
participant pfwA as pfw-A
participant pfwB as pfw-B
participant LanB as app-BLanA->>pfwA: Packet to 10.20.10.20
pfwA->>pfwA: Encrypt with ESP
pfwA->>pfwB: ESP over wan-sim
pfwB->>pfwB: Decrypt, verify auth
pfwB->>LanB: Plaintext on LAN
LanB->>pfwB: Reply
pfwB->>pfwA: Encrypted reply
pfwA->>LanA: Deliver plaintext

## Firewall policy

Both firewalls run nftables with default-deny policies.

- **INPUT** (traffic to the firewall itself): drop by default; allow established, ICMP, SSH from MGMT, IKE/ESP from WAN
- **FORWARD** (traffic through the firewall): drop by default; allow LAN-to-remote-LAN via tunnel, allow LAN-to-MGMT for dev internet access
- **NAT**: masquerade LAN-to-MGMT so internal VMs can reach the internet via the firewall's MGMT interface

All drops are logged with a rate limit.

## Access paths

### 1. Operator to any VM (MGMT plane)

Every VM has a Shared Network interface (192.168.64.0/24). Used for build and debug only. Analogous to an out-of-band management network. See ADR 003.

### 2. External user to Site B (via bastion)

Single sanctioned external entry. Bastion-B enforces public-key only SSH, AllowUsers restriction, fail2ban, modern ciphers, short grace times, and an authorization banner. See ADR 005.

### 3. Site A user to Site B internal website

HTTP request flows through pfw-A, across the IPsec tunnel, through pfw-B, and onto app-B. Reverse direction returns the HTML. A request from outside this path (e.g., the public internet) would not match any forward-accept rule on pfw-B and would be silently dropped.

## IP addressing plan

| Site | Subnet | Purpose |
|---|---|---|
| Site A | 10.10.10.0/24 | Site A LAN (all Site A services) |
| Site B | 10.20.10.0/24 | Site B LAN (all Site B services) |
| Inter-site WAN | 10.255.0.0/24 | Simulated public between pfw WAN interfaces |
| MGMT | 192.168.64.0/24 | Operator access (UTM Shared Network) |

The target plan from team architecture notes uses per-zone subdivision (Management / Infrastructure / Users / DMZ / Monitoring). Lab implementation uses a single LAN per site for simplicity; the addressing convention `10.[site].[zone].0/24` is preserved for future expansion.

## Inventory of VMs

| VM | Site | LAN IP | MGMT IP | Role |
|---|---|---|---|---|
| pfw-A | A | 10.10.10.1 + 10.255.0.1 (WAN) | 192.168.64.26 | Firewall, IPsec peer, NAT |
| pfw-B | B | 10.20.10.1 + 10.255.0.2 (WAN) | 192.168.64.28 | Firewall, IPsec peer, NAT |
| bastion-B | B | 10.20.10.10 | 192.168.64.29 | SSH jump host |
| app-B | B | 10.20.10.20 | 192.168.64.30 | nginx + PostgreSQL, internal website |

MGMT IPs are DHCP-assigned and may shift between reboots.

## Stack summary

| Layer | Tool | Rationale |
|---|---|---|
| Hypervisor | UTM (QEMU) | ARM-native on Apple Silicon; substitute for Proxmox |
| Base OS | Ubuntu Server 24.04 LTS (ARM64) | LTS, mainstream, solid ARM support |
| Firewall | nftables | Modern Linux packet filter; substitute for pfSense's pf |
| Site-to-site VPN | strongSwan (charon-systemd) | Mainstream IKEv2 implementation |
| Web server | nginx | Standard |
| Database | PostgreSQL 16 | Prep for future NetBox install |
| SSH hardening | OpenSSH + fail2ban | Standard |
| Config capture | Git, with redacted secrets | Version control for infra changes |
| Secrets (current) | Local files, chmod 600 | Temporary; migrating to Vault |

## Documented decisions

See `docs/decisions/`:

- ADR 001 — ARM-native substitutes for Proxmox and pfSense
- ADR 002 — Golden image approach for VM provisioning
- ADR 003 — Out-of-band management plane
- ADR 004 — IPsec site-to-site VPN (over OpenVPN)
- ADR 005 — Bastion host on Site B
- ADR 006 — Static routes on Site B VMs for tunnel reachability

## Runbooks

See `docs/runbooks/`:

- `ipsec-tunnel.md` — health check, initiate, teardown, PSK rotation
- `bastion-access.md` — operator access patterns, hardening verification

## Verified working paths (as of last integration test)

| Path | Status |
|---|---|
| Mac -> pfw-A (MGMT SSH) | Pass |
| Mac -> pfw-B (MGMT SSH) | Pass |
| Mac -> bastion-B (MGMT SSH, key auth) | Pass |
| Mac -> app-B (MGMT SSH) | Pass |
| pfw-A LAN -> pfw-B LAN (tunnel, ping) | Pass |
| pfw-A LAN -> bastion LAN (tunnel, ping) | Pass |
| pfw-A LAN -> app-B LAN (tunnel, ping) | Pass |
| bastion -> pfw-A SSH (via tunnel) | Pass |
| bastion -> app-B HTTP (same LAN) | Pass |
| pfw-A LAN -> app-B HTTP (via tunnel) | Pass |
| app-B -> Site A return path (rp_filter passes) | Pass |

## Known limitations

- VM provisioning is manual via UTM (no Terraform provider for UTM); post-provisioning config is destined for Ansible but currently manual.
- DHCP on the MGMT plane means operator IPs change between VM reboots.
- PSK for IPsec is stored in a local file rather than a secret manager; migration to Vault is tracked.
- "Internet cannot reach internal website" is proven by inspection of firewall rules rather than by actual external probe (UTM topology does not simulate public internet).
- `strongswan-starter` package conflicts with `charon-systemd` and has been removed; only the modern daemon is used.
- Cloning VMs in UTM does not regenerate MAC addresses by default; manual MAC change or enabling the setting in UTM global preferences is required before boot to prevent L2 conflicts.

## Next steps

See `docs/NEXT_SESSION.md` for the current pickup point
