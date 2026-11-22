# shellcheck shell=bash
output_file=$1
nixpkgs_revision=$2
nixpkgs_time=$3
# The activated system, to compare with the booted one; none on macOS.
system=${4:-}

switch_time=$(stat --format=%Y /nix/var/nix/profiles/system)

# A system's kernel version, as its modules directory is named.
kernel_version() {
  local directories=("$1"/kernel-modules/lib/modules/*)
  basename "${directories[0]}"
}

mkdir -p "$(dirname "$output_file")"
temporary_file=$(mktemp "$output_file.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT

{
  echo '# HELP system_nixpkgs_info The nixpkgs revision the running system was built from.'
  echo '# TYPE system_nixpkgs_info gauge'
  echo "system_nixpkgs_info{revision=\"$nixpkgs_revision\"} 1"
  echo '# HELP system_nixpkgs_timestamp_seconds When that nixpkgs revision was committed.'
  echo '# TYPE system_nixpkgs_timestamp_seconds gauge'
  echo "system_nixpkgs_timestamp_seconds $nixpkgs_time"
  echo '# HELP system_switch_timestamp_seconds When the system profile last changed: the last deploy or rollback.'
  echo '# TYPE system_switch_timestamp_seconds gauge'
  echo "system_switch_timestamp_seconds $switch_time"
  if [ -n "$system" ]; then
    reason=
    # Activating at boot: /run/booted-system doesn't exist yet.
    if [ -e /run/booted-system ]; then
      booted=$(kernel_version /run/booted-system)
      activated=$(kernel_version "$system")
      if [ "$booted" != "$activated" ]; then
        reason="kernel $booted → $activated"
      elif [ "$(readlink -f "$system/kernel")" != "$(readlink -f /run/booted-system/kernel)" ] \
        || [ "$(readlink -f "$system/kernel-modules")" != "$(readlink -f /run/booted-system/kernel-modules)" ]; then
        reason="kernel rebuilt"
      fi
    fi
    echo '# HELP reboot_required 1 if the activated kernel or its modules differ from the booted ones; the reason label says how.'
    echo '# TYPE reboot_required gauge'
    if [ -n "$reason" ]; then
      echo "reboot_required{reason=\"$reason\"} 1"
    else
      echo 'reboot_required 0'
    fi
  fi
} > "$temporary_file"

chmod 0644 "$temporary_file"
mv "$temporary_file" "$output_file"
