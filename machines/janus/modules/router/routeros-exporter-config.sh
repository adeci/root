# shellcheck shell=bash
# Adds the API password to each exporter device.
base_config=$1
output_file=$2

password=$(tr -d '\n' < "$CREDENTIALS_DIRECTORY/routeros-password")
temporary_file=$(mktemp "$output_file.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT

jq --arg password "$password" \
  '.devices |= map(. + { password: $password })' \
  "$base_config" > "$temporary_file"
chmod 0600 "$temporary_file"
mv "$temporary_file" "$output_file"
trap - EXIT
