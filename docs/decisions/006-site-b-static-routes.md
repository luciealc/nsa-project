# ADR 006 — Static routes on Site B VMs for tunnel reachability

## Context

Each Site B VM (bastion, app-B, future others) has two interfaces:

- `enp0s1` — siteB-lan production interface (10.20.10.0/24)
- `enp0s2` — Shared Network MGMT plane, DHCP from UTM

The default route on these VMs is set via DHCP on `enp0s2`, which points at
the UTM-provided gateway for internet access. Without further configuration,
any packet destined for Site A (10.10.10.0/24) goes out `enp0s2` instead of
through pfw-B, bypassing the IPsec tunnel.

Additionally, Linux's default reverse-path filtering (rp_filter=1) drops
incoming packets whose source IP isn't reachable via the interface they
arrived on. Without a route for 10.10.10.0/24 via `enp0s1`, packets from
Site A arriving on `enp0s1` are silently dropped by the kernel before they
reach tcpdump or any application — which caused a confusing debugging
session where ping requests were visible on pfw-B's forwarding interface
but not on the destination VM.

## Decision

Every Site B VM that needs to be reachable from Site A receives an
explicit static route in netplan:

    routes:
      - to: 10.10.10.0/24
        via: 10.20.10.1

This tells the kernel "to reach Site A, send packets to pfw-B" — which
then tunnels them via IPsec. The same route also satisfies rp_filter's
reverse-path check, so inbound packets from Site A are no longer dropped.

## Applied to

- bastion-B
- app-B
- Any future Site B VM must also include this route

Symmetric rule applies to future Site A VMs needing to reach Site B:
`routes: to: 10.20.10.0/24 via: 10.10.10.1`.

## Alternative considered

Make pfw-B the default gateway for all siteB-lan VMs.

This would eliminate the need for per-VM routes but would force all
internet traffic from Site B VMs to exit via pfw-B, which would then need
proper internet egress. Currently pfw-B reaches the internet only via its
own MGMT interface. Rejected.

## Consequences

- Every new Site B VM needs the static route added manually (until Ansible
  migration).
- Tracked as a standard item in the VM build checklist.

## Status

Accepted.
