# shellcheck shell=bash
control=$(mktemp -d)
close_tunnel() {
  ssh -q -S "$control/socket" -O exit "$TUNNEL_HOST" || true
  # Once backgrounded, ssh only reports here, e.g. when the host can't reach an endpoint.
  cat "$control/log" >&2
  rm -rf "$control"
}
trap close_tunnel EXIT

forwards=()
for forward in $TUNNEL_FORWARDS; do
  forwards+=(-L "127.0.0.1:$forward")
done

# Own master: a shared one keeps the forwards, and its ControlPersist can close this mid-prompt.
if ! ssh -f -N -M -S "$control/socket" -o ControlPersist=no \
  -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ExitOnForwardFailure=yes -E "$control/log" \
  "${forwards[@]}" "$TUNNEL_HOST"; then
  echo "No tunnel through $TUNNEL_HOST, so tofu cannot reach the providers' endpoints:" >&2
  exit 1
fi

"$@"
