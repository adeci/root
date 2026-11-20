# shellcheck shell=bash
# A fixed client on the mgmt bridge must get a lease and resolve through its DNS.
namespace=deploy-guard
udhcpc_log=$(mktemp)
trap 'ip netns delete "$namespace" 2>/dev/null || true; rm -f "$udhcpc_log"' EXIT
ip netns delete "$namespace" 2>/dev/null || true
ip netns add "$namespace"
# Deleting the namespace deletes the client's end of the pair, and the pair with it.
ip link add deploy-guard type veth peer name client address "$MAC" netns "$namespace"
ip link set deploy-guard master "$BRIDGE" up
ip -n "$namespace" link set lo up
ip -n "$namespace" link set client up

# udhcpc is chatty; show its log only when no lease comes.
if ! resolver=$(ip netns exec "$namespace" "$BUSYBOX" udhcpc -i client -n -q -t 5 -T 2 -x "hostname:$CLIENT_NAME" -s "$ON_LEASE" 2>"$udhcpc_log"); then
  cat "$udhcpc_log" >&2
  echo "No lease from janus on $BRIDGE."
  exit 1
fi
answer=$(ip netns exec "$namespace" dig +short +time=2 +tries=2 "@$resolver" "$NAME" || true)
if [[ $answer != "$ADDRESS" ]]; then
  echo "$resolver answered '$answer' for $NAME, not $ADDRESS."
  exit 1
fi
