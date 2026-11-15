# shellcheck shell=bash
output_file=$1
nixpkgs_revision=$2
nixpkgs_time=$3
# The system being activated, compared with the booted one; macOS passes none, having no kernel of its own to swap.
system=${4:-}

switch_time=$(stat --format=%Y /nix/var/nix/profiles/system)

mkdir -p "$(dirname "$output_file")"
temporary_file=$(mktemp "$output_file.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT

{
  echo '# HELP system_nixpkgs_info The nixpkgs revision the running system was built from.'
  echo '# TYPE system_nixpkgs_info gauge'
  echo "system_nixpkgs_info{revision=\"$nixpkgs_revision\",revision_short=\"${nixpkgs_revision:0:7}\"} 1"
  echo '# HELP system_nixpkgs_timestamp_seconds When that nixpkgs revision was committed.'
  echo '# TYPE system_nixpkgs_timestamp_seconds gauge'
  echo "system_nixpkgs_timestamp_seconds $nixpkgs_time"
  echo '# HELP system_switch_timestamp_seconds When the system profile last changed: the last deploy or rollback.'
  echo '# TYPE system_switch_timestamp_seconds gauge'
  echo "system_switch_timestamp_seconds $switch_time"
  if [ -n "$system" ]; then
    reboot_required=0
    # At boot the booted system is the one being activated, and its link does not exist yet.
    if [ -e /run/booted-system ]; then
      for part in kernel initrd kernel-modules; do
        if [ "$(readlink -f "$system/$part")" != "$(readlink -f "/run/booted-system/$part")" ]; then
          reboot_required=1
        fi
      done
    fi
    echo '# HELP reboot_required 1 if the activated kernel, initrd or kernel modules differ from the booted ones.'
    echo '# TYPE reboot_required gauge'
    echo "reboot_required $reboot_required"
  fi
} > "$temporary_file"

chmod 0644 "$temporary_file"
mv "$temporary_file" "$output_file"
