# Runbook — Bastion access

## Operator access (Mac -> bastion)

SSH key authentication from the operator Mac to bastion via MGMT plane:

```bash
ssh cia@<bastion-mgmt-ip>
```

Key is the Mac's ~/.ssh/id_ed25519, public half in bastion's
~cia/.ssh/authorized_keys.

## Bastion -> internal hosts

From the bastion, SSH to any internal IP (Site A or Site B) works per
firewall rules. For Site A hosts, traffic transits the IPsec tunnel via
pfw-B -> pfw-A.

```bash
# Example: reach pfw-A via tunnel
ssh cia@10.10.10.1
```

## Check SSH hardening is in effect

```bash
sudo sshd -T | grep -iE "passwordauth|permitroot|pubkey|allowusers"
```

Expected:

- `permitrootlogin no`
- `passwordauthentication no`
- `pubkeyauthentication yes`
- `allowusers cia`

## Check fail2ban

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

## Unban an IP if you got locked out of a test

```bash
sudo fail2ban-client set sshd unbanip <ip>
```

## Who's logged in right now

```bash
who
last | head -20
```

## Tail live SSH auth attempts

```bash
sudo journalctl -u ssh -f
# or, if journal is sparse:
sudo tail -f /var/log/auth.log
```
