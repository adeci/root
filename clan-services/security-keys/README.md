# Security Keys

Deploys FIDO2 SSH key handles and points SSH at them.

## Roles

- `default` (NixOS only): installs the handle of each key in `use` as
  `~/.ssh/id_ed25519_sk_<name>` of its `owner` account and adds it as an SSH
  `IdentityFile`.

## Notes

- Each key's handle is prompted once and shared by every machine in the
  instance.
