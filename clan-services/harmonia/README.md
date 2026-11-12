# Harmonia

Serves the local nix store as a binary cache with
[harmonia](https://github.com/nix-community/harmonia). Signing keys are
generated and clients trust them through the inventory, so no keys are
distributed by hand.

## Roles

- `server` (NixOS only): runs the harmonia cache on `port`, opened in the
  firewall, and signs what it serves with its generated key.
- `client`: configures nix to use every server as a substituter and trust its
  public key.

## Notes

- Clients reach each server at `<server>.<clan domain>` unless it sets
  `address`.
