# Next session — pick up here

## Status: SITE-TO-SITE IPSEC TUNNEL IS UP ✅

Both firewalls are built, connected, and carrying encrypted traffic between their LANs.

## Current infrastructure state

### pfw-A (Site A firewall)
- MGMT IP: 192.168.64.26 (may shift, verify via `ip -4 addr show enp0s3`)
- WAN (enp0s1): 10.255.0.1/24 on wan-sim
- LAN (enp0s2): 10.10.10.1/24 on siteA-lan
- nftables: default-deny + stateful + IPsec-aware + NAT masquerade
- strongSwan (charon-systemd): siteA-to-siteB tunnel

### pfw-B (Site B firewall)
- MGMT IP: (verify on boot)
- WAN (enp0s1): 10.255.0.2/24 on wan-sim
- LAN (enp0s2): 10.20.10.1/24 on siteB-lan
- Mirror of pfw-A's firewall + strongSwan config

### VPN tunnel
- IKEv2 with PSK auth (lab), AES-GCM-256, ECP-256 DH
- Traffic selectors: 10.10.10.0/24 <-> 10.20.10.0/24
- Comes up on first matching packet (start_action = trap)
- Verified with ping 10.10.10.1 -> 10.20.10.1 crossing tunnel

## Lessons learned this session
- `strongswan-starter` package conflicts with `charon-systemd`; remove it
- swanctl `.secrets` files are NOT included by default — inline `secrets {}`
  block into the `.conf` file
- Cloning VMs in UTM duplicates MAC addresses — enable "Regenerate MAC on clone"
  or manually change MACs post-clone
- `swanctl --list-secrets` doesn't exist; loaded secrets are visible only
  via debug output or by successful authentication

## Next steps in priority order

1. **First internal VM on Site A**: create `svc-A` (Vault + NetBox)
   - Clone ubuntu-golden -> svc-A
   - Attach to: siteA-lan (eth0), Shared Network (MGMT)
   - Static IP on LAN: 10.10.10.10/24 (management subnet service range)
   - Default route via pfw-A LAN interface (10.10.10.1)
   - Re-identify (hostname, machine-id, ssh host keys)

2. **First internal VM on Site B**: create `bastion-B`
   - Same pattern as svc-A
   - Attach to siteB-lan + Shared Network (MGMT)
   - Static IP on LAN: 10.20.40.10/24 (per plan, subnet may differ)

3. **Verify cross-site reachability from LAN VMs**
   - From svc-A, ping bastion-B's LAN IP (should traverse tunnel)

4. **Start introducing Ansible**
   - Inventory with pfw-A, pfw-B, svc-A, bastion-B
   - Roles: baseline, nftables-firewall, strongswan-peer
   - Retrofit existing manual config into idempotent playbooks

5. **Emergency kill-switch**
   - Ansible ad-hoc command to drop the tunnel
   - Documented recovery procedure

## PSK
- Real value in ~/cia-secrets/ipsec-psk.txt (Mac)
- Deployed inline in /etc/swanctl/conf.d/cia-site-to-site.conf on both pfw's
- Redacted in configs/ before git commit
- TODO: migrate to Vault once svc-A is built
