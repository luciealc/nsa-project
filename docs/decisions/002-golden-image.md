# ADR 002 — Golden image approach for VM provisioning

## Context

UTM on Apple Silicon does not expose a reliable Terraform provider or
cloud-init integration comparable to Proxmox. Installing Ubuntu manually
into each of the six project VMs would waste several hours and produce
inconsistent baselines.

## Decision

Build one golden VM (`ubuntu-golden`) with the baseline everything:
- Ubuntu Server 24.04 LTS (ARM64)
- User `cia` with passwordless sudo
- SSH key authentication from the operator Mac
- Timezone Europe/Paris
- Baseline packages: git, curl, python3 (for Ansible), net-tools,
  tcpdump, dnsutils, jq, qemu-guest-agent
- qemu-guest-agent enabled

Each project VM is created by cloning `ubuntu-golden` in UTM, then
re-identified (new hostname, new machine-id, new SSH host keys, new
static IPs) before joining the network.

All host-specific configuration lives in Ansible; the golden image
contains nothing site-specific.

## Consequences

- Fast provisioning (clone ~= 30 seconds vs. 15 minutes of Ubuntu install).
- Consistent baseline across all VMs — drift impossible by construction.
- Golden image is the single point to patch the baseline; re-clone to
  propagate.
- VM provisioning is not fully IaC (UTM clone is a manual step), but
  everything post-clone is Ansible-managed.

## Status

Accepted.
