# ADR 001 — ARM-native substitutes for Proxmox and pfSense

## Context

Host platform is an Apple Silicon Mac (ARM64, 16 GB RAM). The project spec
calls for Proxmox VE and pfSense, both of which only ship for x86_64.
Emulating x86 on ARM is possible but 10–50× slower, making the exercise
unusable in practice.

## Decision

- **Proxmox VE → UTM (QEMU-based hypervisor)**: runs ARM VMs natively at
  near-native speed. VM provisioning is manual via the UTM UI; all
  configuration is managed via Ansible.
- **pfSense → Ubuntu + nftables + strongSwan**: nftables replaces pfSense's
  packet filter, strongSwan provides the IPsec site-to-site tunnel. Both
  are the same underlying technology stack that pfSense uses in its
  FreeBSD userland.
- **OpenVPN (client-to-site)**: kept, runs natively on Linux/ARM.

## Consequences

- Lose the pfSense web UI experience, but gain full nftables IaC via Ansible.
- Lose Proxmox's Terraform provider, but UTM is a reasonable stand-in for
  a learning context.
- The architecture, networking model, VPN topology, firewall ruleset,
  observability stack, and IPAM workflow remain identical to a Proxmox
  + pfSense implementation.

## Status

Accepted.
