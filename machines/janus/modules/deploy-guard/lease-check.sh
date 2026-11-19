# shellcheck shell=bash
# One known client on the mgmt bridge, always with the same address and name, must get a lease from janus and resolve a name through the resolver it names.
namespace=deploy-guard
trap 'ip netns delete "$namespace" 2>/dev/null || true' EXIT
ip netns delete "$namespace" 2>/dev/null || true
ip netns add "$namespace"
# Deleting the namespace deletes the client's end of the pair, and the pair with it.
ip link add deploy-guard type veth peer name client address "$MAC" netns "$namespace"
ip link set deploy-guard master "$BRIDGE" up
ip -n "$namespace" link set lo up
ip -n "$namespace" link set client up

if ! resolver=$(ip netns exec "$namespace" "$BUSYBOX" udhcpc -i client -n -q -t 5 -T 2 -x "hostname:$CLIENT_NAME" -s "$ON_LEASE"); then
  echo "No lease from janus on $BRIDGE."
  exit 1
fi
answer=$(ip netns exec "$namespace" dig +short +time=2 +tries=2 "@$resolver" "$NAME" || true)
if [[ $answer != "$ADDRESS" ]]; then
  echo "$resolver answered '$answer' for $NAME, not $ADDRESS."
  exit 1
fi
