# shellcheck shell=bash
output_file=$1

temporary_file=$(mktemp "$output_file.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT

# Empty for a machine whose key never expires.
expiry=$(tailscale status --json | jq '.Self.KeyExpiry // empty | fromdate')

{
  if [[ -n $expiry ]]; then
    echo "# HELP tailscale_key_expiry_timestamp_seconds When this machine's Tailscale key expires."
    echo '# TYPE tailscale_key_expiry_timestamp_seconds gauge'
    echo "tailscale_key_expiry_timestamp_seconds $expiry"
  fi
} > "$temporary_file"

chmod 0644 "$temporary_file"
mv "$temporary_file" "$output_file"
