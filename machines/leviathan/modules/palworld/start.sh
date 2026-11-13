# shellcheck shell=bash
server_dir=$1
settings_json=$2
patch_settings=$3
# Empty unless the server is listed publicly.
public_address=$4
shift 4

mkdir -p "$server_dir"
steamcmd \
  +force_install_dir "$server_dir" \
  +login anonymous \
  +app_update 2394010 validate \
  +quit

public_ip=
community_args=()
if [ -n "$public_address" ]; then
  if ! public_ip="$(getent ahostsv4 "$public_address" | awk 'NR == 1 { print $1; exit }')" ||
    [ -z "$public_ip" ]; then
    echo "failed to resolve Palworld public address: $public_address" >&2
    exit 1
  fi
  community_args=("-publicip=$public_ip")
fi

settings_file="$server_dir/Pal/Saved/Config/LinuxServer/PalWorldSettings.ini"
install -D -m 0600 "$server_dir/DefaultPalWorldSettings.ini" "$settings_file"
python3 "$patch_settings" \
  "$settings_file" \
  "$settings_json" \
  "$CREDENTIALS_DIRECTORY/admin-password" \
  "$CREDENTIALS_DIRECTORY/server-password" \
  "$public_ip"
exec steam-run "$server_dir/PalServer.sh" "$@" "${community_args[@]}"
