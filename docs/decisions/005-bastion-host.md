# ADR 005 — Bastion host on Site B

## Context

Project spec requires "external access to the remote site via a bastion
host". The bastion is the sole officially-sanctioned entry point into
Site B's internal network from outside, and by extension (via the IPsec
tunnel) into Site A as well.

## Decision

- **Location**: Site B (the "remote" site per spec)
- **Hostname**: bastion-B
- **Network placement**: lab simplification — single LAN per site, so bastion
  lives on siteB-lan (10.20.10.10/24). Production intent per the addressing
  plan is a dedicated DMZ subnet 10.20.40.0/24 behind its own VLAN on pfw-B.
- **Authentication**: SSH public keys only, no passwords
- **Allowed users**: cia (operator), AllowUsers enforced in sshd_config
- **Protection**: fail2ban on sshd, modern-crypto-only kex/cipher/MAC
  (curve25519, chacha20-poly1305, AES-GCM, SHA2-ETM)
- **Session controls**: MaxAuthTries 3, LoginGraceTime 30s, idle disconnect
  after 5 minutes
- **Banner**: /etc/issue.net displays authorization warning at login
- **Logging**: VERBOSE sshd logs (will be shipped to Elastic in a later
  milestone)
- **Routing**: static route to 10.10.10.0/24 via pfw-B (10.20.10.1) so that
  bastion can reach Site A hosts via the IPsec tunnel

## Firewall integration

pfw-A's nftables input chain received an explicit rule permitting SSH from
bastion-B's LAN IP:

    ip saddr 10.20.10.10 tcp dport 22 accept

All other WAN/LAN SSH to pfw-A remains denied; only MGMT-plane SSH (from the
operator Mac) and bastion SSH are permitted to reach port 22.

## Consequences

- Bastion is a single point of entry = single point of failure for external
  admin access
- In DR, the MGMT plane remains as a fallback operator access path
- Follow-up: bastion should hold per-host SSH keys to reach internal VMs,
  not rely on password auth to downstream hosts (tracked as TODO)
- Follow-up: once Elastic is up, ship bastion sshd logs centrally for audit

## Status

Accepted.
