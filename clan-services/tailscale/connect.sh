# shellcheck shell=bash
auth_key_file=$1
shift

state=$(tailscale status --json --peers=false | jq -r .BackendState)
case $state in
  # Only a logged-out Mac uses the key: logging in again with it, a user's key, would take the Mac's tags away.
  NeedsLogin)
    tailscale up --auth-key="file:$auth_key_file" --timeout=30s "$@"
    ;;
  # tailscaled hasn't settled yet; launchd runs this again.
  NoState | Starting)
    exit 1
    ;;
  *)
    tailscale set "$@"
    ;;
esac
