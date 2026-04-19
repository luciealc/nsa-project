# Runbook — IPsec site-to-site tunnel

## Health check

On either pfw-A or pfw-B:

```bash
sudo swanctl --list-sas | grep -v "^plugin "
```

Healthy state: one `ESTABLISHED` IKE SA and one `INSTALLED, TUNNEL` CHILD_SA.
Packet and byte counters should be growing if traffic is flowing.

## Functional test

From pfw-A:
```bash
ping -c 3 -I 10.10.10.1 10.20.10.1
```

From pfw-B:
```bash
ping -c 3 -I 10.20.10.1 10.10.10.1
```

## Manual initiate (if the trap hasn't triggered)

From pfw-A:
```bash
sudo swanctl --initiate --child lan-to-lan
```

## Manual teardown (emergency cut-off)

From either peer:
```bash
sudo swanctl --terminate --ike siteA-to-siteB    # on pfw-A
sudo swanctl --terminate --ike siteB-to-siteA    # on pfw-B
```

Or nuke all tunnels:
```bash
sudo systemctl restart strongswan
```

## Reload config after changes

```bash
sudo swanctl --load-all 2>&1 | grep -v "^plugin "
```

Look for `successfully loaded N connections` and `successfully loaded N secrets`.

## Common issues

| Symptom | Cause | Fix |
|---|---|---|
| `no shared key found for X - Y` | `.secrets` file not loaded | inline the `secrets {}` block into the `.conf` file |
| `Destination Host Unreachable` between WAN IPs | Duplicate MAC addresses between VMs, or different UTM host networks | Ensure unique MACs; verify both VMs on same "wan-sim" |
| `Connection refused` on `swanctl` socket | `strongswan-starter` running alongside `charon-systemd` | `apt remove strongswan-starter`; only `strongswan.service` should exist |
| Tunnel up but no traffic | Firewall rules dropping forwarded packets | Check `sudo nft list ruleset`; look for allow rules on LAN-to-LAN forward |

## Rotate the PSK

1. Generate new PSK: `openssl rand -base64 48`
2. Update `secret = "..."` on both pfw-A and pfw-B
3. Reload on both: `sudo swanctl --load-all`
4. Terminate existing SAs so they renegotiate with the new key:
   `sudo swanctl --terminate --ike siteA-to-siteB`
5. Re-initiate if needed: `sudo swanctl --initiate --child lan-to-lan`

## Target state (not yet implemented)

- PSKs retrieved from HashiCorp Vault at Ansible deploy time
- Certificates instead of PSKs (x.509 from an internal CA)
