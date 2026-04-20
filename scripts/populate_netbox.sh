#!/usr/bin/env bash
# CIA project — populate NetBox with the actual IP plan
# Uses NetBox v2 tokens (Bearer auth)

set -euo pipefail

export VAULT_ADDR='http://127.0.0.1:8200'

API="http://10.10.10.20/api"
TOKEN="$(vault kv get -field=token cia/netbox/api)"

if [ -z "$TOKEN" ]; then
  echo "ERROR: no NetBox token in Vault"
  exit 1
fi

H=(-H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json")

post() {
  local path="$1"
  local data="$2"
  curl -sS -X POST "${H[@]}" "$API$path" -d "$data" \
    | python3 -c 'import json,sys; o=json.load(sys.stdin); print(o.get("id", o))'
}

echo "=== Creating sites ==="
SITE_A_ID=$(post /dcim/sites/ '{"name":"Site A","slug":"site-a","status":"active","description":"On-prem site"}')
echo "Site A id: $SITE_A_ID"
SITE_B_ID=$(post /dcim/sites/ '{"name":"Site B","slug":"site-b","status":"active","description":"Remote site"}')
echo "Site B id: $SITE_B_ID"

echo ""
echo "=== Creating prefixes ==="
post /ipam/prefixes/ "{\"prefix\":\"10.10.10.0/24\",\"site\":$SITE_A_ID,\"status\":\"active\",\"description\":\"Site A LAN\"}"
post /ipam/prefixes/ "{\"prefix\":\"10.20.10.0/24\",\"site\":$SITE_B_ID,\"status\":\"active\",\"description\":\"Site B LAN\"}"
post /ipam/prefixes/ "{\"prefix\":\"10.255.0.0/24\",\"status\":\"active\",\"description\":\"Simulated WAN between sites\"}"
post /ipam/prefixes/ "{\"prefix\":\"192.168.64.0/24\",\"status\":\"active\",\"description\":\"Operator MGMT plane (UTM Shared Network)\"}"

echo ""
echo "=== Creating device roles ==="
FW_ROLE_ID=$(post /dcim/device-roles/ '{"name":"Firewall","slug":"firewall","color":"f44336"}')
BASTION_ROLE_ID=$(post /dcim/device-roles/ '{"name":"Bastion","slug":"bastion","color":"ff9800"}')
APP_ROLE_ID=$(post /dcim/device-roles/ '{"name":"App Server","slug":"app-server","color":"2196f3"}')
SVC_ROLE_ID=$(post /dcim/device-roles/ '{"name":"Services","slug":"services","color":"4caf50"}')

echo ""
echo "=== Creating manufacturer + device type ==="
MANUF_ID=$(post /dcim/manufacturers/ '{"name":"UTM QEMU","slug":"utm-qemu"}')
DEVTYPE_ID=$(post /dcim/device-types/ "{\"manufacturer\":$MANUF_ID,\"model\":\"Ubuntu 24.04 VM\",\"slug\":\"ubuntu-vm\"}")

echo ""
echo "=== Creating devices ==="
post /dcim/devices/ "{\"name\":\"pfw-A\",\"site\":$SITE_A_ID,\"role\":$FW_ROLE_ID,\"device_type\":$DEVTYPE_ID,\"status\":\"active\"}"
post /dcim/devices/ "{\"name\":\"pfw-B\",\"site\":$SITE_B_ID,\"role\":$FW_ROLE_ID,\"device_type\":$DEVTYPE_ID,\"status\":\"active\"}"
post /dcim/devices/ "{\"name\":\"bastion-B\",\"site\":$SITE_B_ID,\"role\":$BASTION_ROLE_ID,\"device_type\":$DEVTYPE_ID,\"status\":\"active\"}"
post /dcim/devices/ "{\"name\":\"app-B\",\"site\":$SITE_B_ID,\"role\":$APP_ROLE_ID,\"device_type\":$DEVTYPE_ID,\"status\":\"active\"}"
post /dcim/devices/ "{\"name\":\"svc-A\",\"site\":$SITE_A_ID,\"role\":$SVC_ROLE_ID,\"device_type\":$DEVTYPE_ID,\"status\":\"active\"}"

echo ""
echo "=== Creating LAN IP addresses ==="
post /ipam/ip-addresses/ "{\"address\":\"10.10.10.1/24\",\"status\":\"active\",\"description\":\"pfw-A LAN interface\"}"
post /ipam/ip-addresses/ "{\"address\":\"10.20.10.1/24\",\"status\":\"active\",\"description\":\"pfw-B LAN interface\"}"
post /ipam/ip-addresses/ "{\"address\":\"10.20.10.10/24\",\"status\":\"active\",\"description\":\"bastion-B LAN\"}"
post /ipam/ip-addresses/ "{\"address\":\"10.20.10.20/24\",\"status\":\"active\",\"description\":\"app-B LAN\"}"
post /ipam/ip-addresses/ "{\"address\":\"10.10.10.20/24\",\"status\":\"active\",\"description\":\"svc-A LAN\"}"
post /ipam/ip-addresses/ "{\"address\":\"10.255.0.1/24\",\"status\":\"active\",\"description\":\"pfw-A WAN (wan-sim)\"}"
post /ipam/ip-addresses/ "{\"address\":\"10.255.0.2/24\",\"status\":\"active\",\"description\":\"pfw-B WAN (wan-sim)\"}"

echo ""
echo "=== Done. Check NetBox UI to verify. ==="
