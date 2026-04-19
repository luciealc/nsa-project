# ADR 003 — Out-of-band management plane

## Context

UTM's "Host Only" networks do not automatically expose a host-side IP
on the Mac, so VMs attached only to those networks are unreachable from
the operator workstation. In production infrastructure, firewalls and
servers typically have a dedicated management interface separate from
production data paths (WAN/LAN), commonly called "out-of-band
management".

## Decision

Every project VM gets an additional NIC on UTM's "Shared Network",
representing its out-of-band management interface. This NIC:

- Receives an IP via UTM's internal DHCP (192.168.64.0/24)
- Provides SSH access from the operator's Mac
- Provides outbound internet for `apt`, time sync, etc.
- Is NOT part of the simulated production network (siteA-lan, siteB-lan,
  wan-sim)
- Is NOT protected by the firewall rules defined on the VM itself

In a production deployment, this interface would live on a dedicated
admin VLAN behind a separate jump host / bastion, not on the public
internet. For the local lab, Shared Network is an acceptable stand-in.

## Consequences

- Three-interface pattern on firewalls: WAN / LAN / MGMT
- Two-interface pattern on servers: role-network / MGMT
- Bastion host remains the "official" admin entry point per the project
  spec; the MGMT plane is the operator's back-door for build and debug
- Documented deviation from a pure production topology; must be noted
  in final delivery

## Status

Accepted.
