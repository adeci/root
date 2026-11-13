# Remote Builder

Nix remote building over SSH as a dedicated `nix` user, with a key pair
generated per client.

## Roles

- `server` (NixOS or nix-darwin): creates the trusted `nix` user and authorizes
  every client's public key, plus `externalKeys`, on it.
- `client`: registers every other server, at `<server>.<clan domain>`, as a nix
  build machine for the builds `offload` selects.

## Notes

- Servers skip clients whose key has not been generated yet: run
  `clan vars generate <client>` before deploying servers that should trust it.
- `--builders @/etc/nix/machines-all --max-jobs 0` lets one build use every
  server, whatever `offload` says.
