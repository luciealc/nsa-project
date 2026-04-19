# CIA — Hybrid Infrastructure Project

Deployment and securing of a hybrid infrastructure, simulated locally on Apple Silicon.

## Context

This repository is a personal reimplementation of the Epitech CIA project,
adapted to run locally on macOS (Apple Silicon / ARM) using UTM instead of
Proxmox, and nftables/strongSwan instead of pfSense, to preserve the
architecture and skills while accommodating the host platform.

## Structure

- `docs/` — architecture, runbooks, decision records
- `terraform/` — IaC (where feasible)
- `ansible/` — configuration management for all VMs
- `scripts/` — helper shell scripts
- `isos/` — installation media (gitignored)

## Status

In progress.
