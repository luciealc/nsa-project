# Next session — pick up here

## Status: pfw-A complete, pfw-B pending

## What's working on pfw-A (192.168.64.26 MGMT)
- Three NICs: WAN (enp0s1) = 10.255.0.1, LAN (enp0s2) = 10.10.10.1, MGMT (enp0s3) DHCP
- IP forwarding enabled + sysctl hardening
- nftables: default-deny forward, stateful, SSH from MGMT, IPsec from WAN
- NAT masquerade: siteA-lan -> MGMT (lab internet access for LAN VMs)
- strongSwan (via charon-systemd): IKEv2 config for siteA-to-siteB tunnel
  loaded and waiting for peer
- Config files archived at configs/pfw-A/

## PSK
- Stored in ~/cia-secrets/ipsec-psk.txt on the Mac
- Stored in /etc/swanctl/conf.d/cia-site-to-site.secrets on pfw-A
- Will need to match exactly on pfw-B
- Target: migrate to Vault (tracked in ADR 004)

## Next steps in priority order

1. Build pfw-B (estimate 25-35 min)
   - Clone ubuntu-golden in UTM -> pfw-B
   - Attach NICs: wan-sim (WAN), siteB-lan (LAN), Shared Network (MGMT)
   - Re-identify: hostname, machine-id, regen SSH host keys
   - Netplan:
     - enp0s1 = 10.255.0.2/24 (WAN)
     - enp0s2 = 10.20.10.1/24 (LAN)
     - enp0s3 = DHCP (MGMT)
   - Sysctl: enable forwarding + hardening
   - nftables: mirror of pfw-A with A<->B swapped
   - Install strongswan + charon-systemd
   - Copy configs/pfw-B/etc/swanctl/conf.d/*.conf from repo
   - Create /etc/swanctl/conf.d/cia-site-to-site.secrets with matching PSK
   - swanctl --load-all

2. Test the tunnel
   - From pfw-A: `swanctl --initiate --child lan-to-lan` (or send a packet
     from LAN that matches the selector)
   - `swanctl --list-sas` should show an established SA on both sides
   - ping from 10.10.10.1 (pfw-A LAN) to 10.20.10.1 (pfw-B LAN) should work

3. Add first internal VM (Site A Vault+NetBox VM) so traffic can cross
   the tunnel from a "real" LAN host

4. Start Ansible-ifying what we built manually
   - Inventory with pfw-A, pfw-B, and future VMs on MGMT IPs
   - Roles: baseline, nftables-firewall, strongswan-peer

## Known issues / caveats
- UTM network "wan-sim" is labeled "Network 2" in UTM UI (rename bug)
- Ubuntu 24.04 ARM: use `charon-systemd` package, not `strongswan-starter`
- Shared Network DHCP: MGMT IPs may change between boots; rely on them
  staying fairly stable, but verify after each boot
