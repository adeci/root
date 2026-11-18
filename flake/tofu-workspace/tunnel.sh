# shellcheck shell=bash
control=$(mktemp -d)
close_tunnel() {
  ssh -q -S "$control/socket" -O exit "$TUNNEL_HOST" || true
  # Once backgrounded, ssh reports only here, as when the host cannot reach a forward's endpoint.
  cat "$control/log" >&2
  rm -rf "$control"
}
trap close_tunnel EXIT

forwards=()
for forward in $TUNNEL_FORWARDS; do
  forwards+=(-L "127.0.0.1:$forward")
done

# Its own master: one shared through the user's ControlMaster setting would keep the forwards after the command, and their ControlPersist would close this one while tofu waits for a yes.
# A host that is down, or a local port that is taken, fails the command at once; a path that dies later ends it within a minute, where tofu would wait for ever.
if ! ssh -f -N -M -S "$control/socket" -o ControlPersist=no \
  -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ExitOnForwardFailure=yes -E "$control/log" \
  "${forwards[@]}" "$TUNNEL_HOST"; then
  echo "No tunnel through $TUNNEL_HOST, so tofu cannot reach the providers' endpoints:" >&2
  exit 1
fi

"$@"
