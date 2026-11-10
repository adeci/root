# shellcheck shell=bash
cred="$HOME/.config/keyring-tpm/password.cred"
keyring="$HOME/.local/share/keyrings/login.keyring"

if [[ ! -e $cred ]]; then
  if [[ -e $keyring ]]; then
    echo "keyring-tpm: $keyring has no sealed password yet; run keyring-tpm-setup" >&2
    exit 2
  fi
  # Fresh home: seal a random password; the daemon creates the keyring with it.
  mkdir -p "$(dirname "$cred")"
  head -c 32 /dev/urandom | base64 -w0 |
    systemd-creds encrypt --user --name=keyring-tpm - "$cred"
fi

password=$(systemd-creds decrypt --user --name=keyring-tpm "$cred" -)
# --replace takes over from a daemon a client may have D-Bus-activated first.
exec /run/wrappers/bin/gnome-keyring-daemon --replace --foreground --unlock \
  --components=secrets < <(printf '%s' "$password")
