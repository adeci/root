#!/usr/bin/env bash
set -euo pipefail

check=false
if [[ ${1:-} == --check ]]; then
  check=true
  shift
fi

if [[ $# != 1 || $1 != /* ]]; then
  echo 'Usage: pi-profile-install [--check] /absolute/path/to/.pi/agent' >&2
  exit 2
fi

profile=@profile@
destination=$1
files=(AGENTS.md APPEND_SYSTEM.md themes/tokyo-night.json)

# Check every file before replacing any. Only adopt identical files or our own links.
for relative in "${files[@]}"; do
  target="$destination/$relative"
  if [[ -L $target ]]; then
    case "$(readlink -- "$target")" in
      /nix/store/*-pi-profile/share/pi-profile/"$relative") continue ;;
    esac
  elif [[ ! -e $target ]] || { [[ -f $target ]] && cmp -s -- "$profile/$relative" "$target"; }; then
    continue
  fi
  printf 'pi-profile: refusing to replace %s; review and back up or move it first.\n' "$target" >&2
  exit 1
done

if "$check"; then
  exit 0
fi

mkdir -p -- "$destination/themes"
for relative in "${files[@]}"; do
  ln -sfnT -- "$profile/$relative" "$destination/$relative"
done
