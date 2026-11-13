# shellcheck shell=bash
owner=$1
handle=$2
identity_file=$3

install -d -m 700 -o "$owner" "$(dirname "$identity_file")"
install -m 600 -o "$owner" "$handle" "$identity_file"
# OpenSSH rejects a key file without a final newline.
if [[ "$(tail -c1 "$identity_file")" != "" ]]; then
  echo >>"$identity_file"
fi
