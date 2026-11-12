# Remote Builder

Configures nix remote building with per-client SSH keys and a dedicated `nix`
build user. Each client generates its own key pair, and servers authorize
every client's public key automatically.

## Roles

- `server` (NixOS only): creates the trusted `nix` user and authorizes the
  clients' keys plus `externalKeys` for it.
- `client`: registers every other server, at `<server>.<clan domain>`, as a nix
  build machine for the builds `offload` selects.

## Notes

- Servers skip clients whose key has not been generated yet: run
  `clan vars generate <client>` before deploying servers that should trust it.
- `/etc/nix/machines-all` always lists every server, for opting in per build
  with `--builders @/etc/nix/machines-all --max-jobs 0`.
