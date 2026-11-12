# Security Keys

Deploys FIDO2 SSH key handles to their owners' `~/.ssh/` and configures SSH to
use them.

## Roles

- `default` (NixOS only): installs the handle of each key in `use` as its
  owner's `~/.ssh/id_ed25519_sk_<name>` and adds it as an SSH `IdentityFile`.

## Notes

- Each key's handle is prompted once and shared by every machine in the
  instance.
