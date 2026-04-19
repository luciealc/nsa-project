# Next session — pick up here

## Last session accomplished
- Mac toolchain ready (UTM, Homebrew, Terraform, Ansible, Git)
- Repo and docs structure in place
- UTM host networks: siteA-lan, siteB-lan, wan-sim (= "Network 2" in UI)
- Golden image `ubuntu-golden` built and baselined
- First project VM `pfw-A` cloned, re-identified, networked:
  - enp0s1 (WAN, wan-sim) = 10.255.0.1/24
  - enp0s2 (LAN, siteA-lan) = 10.10.10.1/24
  - enp0s3 (MGMT, Shared Network) = DHCP (192.168.64.x)
- pfw-A reachable via SSH from Mac on its MGMT IP

## Next steps in priority order

1. Build `pfw-B` the same way as `pfw-A`:
   - Clone ubuntu-golden → pfw-B
   - Attach to wan-sim (WAN), siteB-lan (LAN), Shared Network (MGMT)
   - WAN IP: 10.255.0.2/24
   - LAN IP: 10.20.10.1/24
   - Re-identify (hostname, machine-id, ssh host keys)
   - Verify pfw-A and pfw-B can ping each other on wan-sim

2. Set up Ansible inventory now that two hosts exist
   - Define inventory with MGMT IPs
   - First playbook: baseline hardening (SSH config, firewall stance)

3. Install and configure strongSwan on both pfw-A and pfw-B
   - IPsec tunnel between 10.255.0.1 and 10.255.0.2
   - Encrypt traffic between siteA-lan and siteB-lan
   - Test ping 10.10.10.1 -> 10.20.10.1 via the tunnel

4. Install nftables rules
   - Stateful firewall
   - Default deny
   - Allow LAN<->LAN via tunnel
   - Emergency kill-switch script

## Known issues / caveats
- UTM network named "Network 2" internally, referred to as wan-sim in docs
- Shared Network DHCP assigns IPs dynamically; note them each time
- SSH host key cleanup trick broke things; skip that step on clones,
  use `rm /etc/ssh/ssh_host_* && ssh-keygen -A` AFTER boot instead
