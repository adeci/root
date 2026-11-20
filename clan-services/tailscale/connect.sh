# shellcheck shell=bash
auth_key_file=$1
shift

state=$(tailscale status --json --peers=false | jq -r .BackendState)
case $state in
  # Only when logged out: re-login with a user's key would drop the Mac's tags.
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
