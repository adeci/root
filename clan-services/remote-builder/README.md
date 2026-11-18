# Remote Builder

Nix remote building over SSH as a dedicated `nix` user, with a key pair
generated per client.

## Roles

- `server` (NixOS or nix-darwin): creates the trusted `nix` user and authorizes
  every client's public key on it for `nix-daemon --stdio` only: no shell, no
  other command, no forwarding.
  A nix-darwin server with the `linux-builder` feature can share its Linux VM
  through `linuxBuilder`: the VM trusts the same keys on the same terms, and
  clients reach it as `<server>-linux-builder` by jumping through the server,
  whose keys may forward to the VM's SSH port and nowhere else.
- `client`: registers every other server, at `<server>.<clan domain>`, as a nix
  build machine for the builds `offload` selects.

## Notes

- Servers skip clients whose key has not been generated yet: run
  `clan vars generate <client>` before deploying servers that should trust it.
- `--builders @/etc/nix/machines-all --max-jobs 0` lets one build use every
  server, whatever `offload` says.
