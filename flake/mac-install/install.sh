#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: mac-install <machine> <address>" >&2
  exit 1
fi
machine=$1
address=$2
target="root@$address"

cd "$(git rev-parse --show-toplevel)" || exit

control=$(mktemp -d)
secrets=$(mktemp -d)
awake=
cleanup() {
  [ -z "$awake" ] || kill "$awake" 2>/dev/null || true
  ssh -o ControlPath="$control/ssh" -O exit "$target" 2>/dev/null || true
  rm -rf "$control" "$secrets"
}
trap cleanup EXIT
export NIX_SSHOPTS="-o ControlMaster=auto -o ControlPath=$control/ssh -o ControlPersist=10m"
# Options word-split on purpose; commands are built here to run there.
# mac never reads stdin, so polling doesn't eat keypresses meant for
# read; mac_stdin is for the two calls that stream data.
# shellcheck disable=SC2086,SC2029
mac() { ssh -n $NIX_SSHOPTS "$target" "$@"; }
# shellcheck disable=SC2086,SC2029
mac_stdin() { ssh $NIX_SSHOPTS "$target" "$@"; }
section() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

section "$machine"
if ! user=$(nix eval --raw ".#darwinConfigurations.$machine.config.system.primaryUser" 2>/dev/null); then
  echo "no darwinConfigurations.$machine in this flake" >&2
  exit 1
fi
echo "  primary user: $user"

section "Host key of $address"
if ! err=$(timeout 5 bash -c "exec 3<>/dev/tcp/$address/22" 2>&1); then
  case $err in
    *refused*) echo "$address is up but SSH is off: run the bootstrap on the Mac" >&2 ;;
    *"not known"*) echo "can't resolve $address: use the address the bootstrap printed" >&2 ;;
    *) echo "$address doesn't answer on port 22 (asleep, wrong address, or another network)${err:+: ${err##*: }}" >&2 ;;
  esac
  exit 1
fi
scanned=$(ssh-keyscan -T 5 -t ed25519 "$address" 2>/dev/null || true)
if [ -z "$scanned" ]; then
  echo "SSH on $address has no ed25519 host key yet: run sudo ssh-keygen -A on the Mac" >&2
  exit 1
fi
echo "  $(ssh-keygen -lf - <<<"$scanned" | awk '{ print $2 }')"
read -rp "  Same as the one the Mac printed? [y/N] " answer </dev/tty
[ "$answer" = y ] || exit 1
ssh-keygen -R "$address" >/dev/null 2>&1 || true
printf '%s\n' "$scanned" >>~/.ssh/known_hosts

# Keeps the Mac awake (lid open) while this runs: caffeinate lives in its own session with a terminal, so the hangup when that session ends stops it, even if this machine drops off.
# Its own connection, so resetting the shared one below doesn't end it.
ssh -tt -o ControlPath=none "$target" caffeinate -dimsu </dev/null >/dev/null 2>&1 &
awake=$!

section "Full Disk Access for remote users"
# Activation writes files macOS guards even from root, like /etc/pam.d; SSH sessions only get past that with this on, and reading the privacy database later needs it too.
fda_check="/usr/bin/sqlite3 '/Library/Application Support/com.apple.TCC/TCC.db' 'select 1' >/dev/null 2>&1"
# New connections each time: a session opened before the toggle keeps running without it.
fresh() { ssh -n -o ControlPath=none "$target" "$@"; }
if fresh "$fda_check"; then
  echo "  ✓ on"
else
  echo "  → Remote Login (i) > turn on \"Allow full disk access for remote users\""
  uid=$(fresh id -u "$user")
  fresh "launchctl asuser $uid sudo -u $user open 'x-apple.systempreferences:com.apple.Sharing-Settings.extension'"
  echo "    waiting up to 5 minutes"
  deadline=$((SECONDS + 300))
  until fresh "$fda_check"; do
    if ((SECONDS >= deadline)); then
      echo "  still off after 5 minutes; turn it on and run this again" >&2
      exit 1
    fi
    sleep 2
  done
  ssh -o ControlPath="$control/ssh" -O exit "$target" 2>/dev/null || true
  echo "  ✓ on"
fi

section "FileVault"
# A warning, not a stop: turning it on is a separate decision, and it can wait.
if mac "fdesetup isactive" >/dev/null 2>&1; then
  echo "  ✓ on"
else
  echo "  ! off: System Settings > Privacy & Security > FileVault"
fi

section "Secrets"
clan vars generate "$machine"
clan vars upload "$machine" --directory "$secrets"
upload_dir=$(nix eval --raw ".#darwinConfigurations.$machine.config.clan.core.vars.sops.secretUploadDirectory")
tar -C "$secrets" -cf - . | mac_stdin "install -d -m 700 '$upload_dir' && tar -C '$upload_dir' -xpf -"
echo "  uploaded to $upload_dir"

section "Copying the flake"
# Before nix-darwin, Nix isn't on root's PATH over SSH, and the Mac trusts only cache.nixos.org's key, so inputs this machine got from other caches need --no-check-sigs.
flake=$(nix flake archive --json --no-check-sigs \
  --to "ssh-ng://$target?remote-program=/nix/var/nix/profiles/default/bin/nix-daemon" . |
  jq -r .path)
echo "  $flake"

section "First switch (built on the Mac)"
# What `darwin-rebuild switch` does: set the system profile, then
# activate. The installer's nix.conf would block nix-darwin's.
mac_stdin bash -s -- "$flake" "$machine" <<'EOF'
set -euo pipefail
flake=$1 machine=$2
bin=/nix/var/nix/profiles/default/bin
if [ -e /etc/nix/nix.conf ] && [ ! -L /etc/nix/nix.conf ]; then
  mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
fi
system=$("$bin/nix" --extra-experimental-features 'nix-command flakes' \
  build --no-link --print-out-paths "$flake#darwinConfigurations.$machine.system")
"$bin/nix-env" -p /nix/var/nix/profiles/system --set "$system"
"$system/activate"
EOF

section "System Settings"
if ! setup=$(mac cat /etc/mac-setup.json 2>/dev/null); then
  echo "  nothing declared"
else
  uid=$(jq -r .uid <<<"$setup")
  count=$(jq '.steps | length' <<<"$setup")
  # Apps only appear in a Privacy list once they've run, and need a
  # restart to pick up a grant. Backgrounded: a launch can sit behind
  # a dialog.
  restart() {
    for service in $(jq -r '.restart[]' <<<"$1"); do
      mac "launchctl kickstart -k ${service/#gui\//gui/$uid/} >/dev/null 2>&1 &" || true
    done
  }
  for ((i = 0; i < count; i++)); do
    step=$(jq -c ".steps[$i]" <<<"$setup")
    name=$(jq -r .name <<<"$step")
    check=$(jq -r '.check // empty' <<<"$step")
    if [ -n "$check" ] && mac "$check"; then
      echo "  ✓ $name"
      continue
    fi
    echo "  → $name: $(jq -r .instructions <<<"$step")"
    restart "$step"
    mac "launchctl asuser $uid sudo -u $user open '$(jq -r .url <<<"$step")'"
    if [ -n "$check" ]; then
      echo "    waiting for it (Enter skips)"
      until mac "$check"; do
        if read -rt 2 </dev/tty; then break; fi
      done
    else
      read -rp "    Enter when done " </dev/tty
    fi
    restart "$step"
    echo "  ✓ $name"
  done
fi

section "Left for you"
echo "  - FileVault: $(mac fdesetup status)"
