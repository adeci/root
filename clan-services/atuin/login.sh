# shellcheck shell=bash
atuin status >/dev/null 2>&1 && exit 0
atuin login \
  --username "$(<"$USERNAME_FILE")" \
  --password "$(<"$PASSWORD_FILE")" \
  --key "$(<"$KEY_FILE")"
atuin sync
