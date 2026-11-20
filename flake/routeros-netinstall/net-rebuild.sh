# shellcheck shell=bash
if [[ $# -ne 1 ]] || ! jq -e --arg device "$1" 'has($device)' "$DEVICES" >/dev/null; then
  echo "Usage: net-rebuild <device>, one of: $(jq -r 'keys | join(", ")' "$DEVICES")"
  exit 1
fi
device=$1
netinstall=$(jq -r --arg device "$device" '.[$device].netinstall' "$DEVICES")
api_address=$(jq -r --arg device "$device" '.[$device].apiAddress' "$DEVICES")
api_port=$(jq -r --arg device "$device" '.[$device].apiPort' "$DEVICES")

echo "==> After the reinstall this needs the internet and $ROUTER: checking the Terraform state and $ROUTER are reachable..."
echo "    Rebuilding the main switch takes the home network down: use another uplink, e.g. a phone hotspot ($ROUTER is on the tailnet)."
if ! "$STATE" list >/dev/null; then
  echo "This machine can't read the Terraform state; leaving $device as is."
  exit 1
fi
if ! ssh -n -o ConnectTimeout=10 "$ROUTER_HOST" true; then
  echo "This machine can't reach $ROUTER; leaving $device as is."
  exit 1
fi

echo ""
"$netinstall"

# From here `net-apply <device>` alone finishes; no state bucket access fails fast.
echo ""
echo "==> Forgetting $device's old resources in the Terraform state..."
if ! "$STATE_RM_DEVICE" --yes "$device"; then
  echo ""
  echo "$device is reinstalled, but its old resources are still in the Terraform state."
  echo "Once this machine reaches the state bucket and $ROUTER (another uplink if the home network is down), finish with:"
  echo "  nix run .#net-state-rm-device $device"
  echo "  nix run .#net-apply -- $device"
  exit 1
fi
interrupted() {
  echo ""
  echo "$device is reinstalled and forgotten in the Terraform state. Finish with:"
  echo "  nix run .#net-apply -- $device"
  exit 130
}
trap interrupted INT

echo ""
echo "==> Waiting up to 10 minutes for $ROUTER to reach $device's API at $api_address:$api_port..."
deadline=$((SECONDS + 10 * 60))
shown=""
until report=$(ssh -n -o ConnectTimeout=10 "$ROUTER_HOST" nc -vz -w 5 "$api_address" "$api_port" 2>&1); do
  # Show each new reason, so a changed host key or missing nc doesn't look like an unmoved cable.
  if [[ $report != "$shown" ]]; then
    echo "$report"
    shown=$report
  fi
  if ((SECONDS >= deadline)); then
    echo ""
    echo "$device is reinstalled and forgotten in the Terraform state. Once $ROUTER reaches it, finish with:"
    echo "  nix run .#net-apply -- $device"
    exit 1
  fi
  sleep 5
done

echo ""
echo "==> Applying $device's configuration..."
if ! "$APPLY" "$device"; then
  echo ""
  echo "$device is reinstalled and forgotten in the Terraform state, but its configuration did not apply. Finish with:"
  echo "  nix run .#net-apply -- $device"
  exit 1
fi
