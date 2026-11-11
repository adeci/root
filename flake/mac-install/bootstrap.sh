#!/usr/bin/env bash

# Primes a fresh Mac for `mac-install` from an admin machine: installs Nix, turns on Remote Login and authorizes the fleet's SSH keys for root and this user.

set -euo pipefail

repo=${BOOTSTRAP_REPO:-adeci/root}
ref=${BOOTSTRAP_REF:-main}
user_file=${BOOTSTRAP_USER_FILE:-inventory/users/alex.nix}

nix_bin=/nix/var/nix/profiles/default/bin

die() {
  echo "mac-bootstrap: $*" >&2
  exit 1
}

[ "$(uname -s)" = Darwin ] || die "macOS only"
[ "$(id -u)" -ne 0 ] || die "run as your admin user, not root"

echo "==> sudo (asked once, kept alive while this runs)"
# stdin is this script when piped from curl; the password comes from the terminal.
# shellcheck disable=SC2024
sudo -v </dev/tty
while sleep 50; do sudo -n true 2>/dev/null || exit; done &
trap 'kill $! 2>/dev/null || true' EXIT

if [ -x "$nix_bin/nix" ]; then
  echo "==> Nix already installed: $("$nix_bin/nix" --version)"
else
  echo "==> Installing Nix (official multi-user installer)"
  curl -fsSL https://nixos.org/nix/install -o /tmp/nix-install
  # stdin is this script when piped from curl; keep the installer off it.
  sh /tmp/nix-install --daemon --yes </dev/null
  rm -f /tmp/nix-install
fi

echo "==> Remote Login"
# What nix-darwin's openssh module does; systemsetup would need Full Disk Access.
sudo launchctl enable system/com.openssh.sshd
sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true

echo "==> Authorizing keys from $repo:$user_file"
user_nix=$(mktemp)
curl -fsSL "https://raw.githubusercontent.com/$repo/$ref/$user_file" -o "$user_nix"
keys=$("$nix_bin/nix" --extra-experimental-features nix-command eval --raw \
  --file "$user_nix" --apply 'u: builtins.concatStringsSep "\n" u.sshKeys + "\n"')
rm -f "$user_nix"
[ -n "$keys" ] || die "no keys found in $user_file"

add_keys() {
  local home=$1 owner=$2
  sudo install -d -m 700 -o "$owner" "$home/.ssh"
  sudo touch "$home/.ssh/authorized_keys"
  while IFS= read -r key; do
    [ -n "$key" ] || continue
    sudo grep -qxF "$key" "$home/.ssh/authorized_keys" ||
      printf '%s\n' "$key" | sudo tee -a "$home/.ssh/authorized_keys" >/dev/null
  done <<<"$keys"
  sudo chown "$owner" "$home/.ssh/authorized_keys"
  sudo chmod 600 "$home/.ssh/authorized_keys"
}
add_keys /var/root root
add_keys "$HOME" "$(id -un)"

ips=$(ifconfig | awk '/inet / && $2 != "127.0.0.1" { print $2 }' | paste -sd ' ' -)
fingerprint=$(ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub | awk '{ print $2 }')

cat <<EOF

Ready. This Mac:
  addresses:     $ips
  SSH host key:  $fingerprint

EOF
