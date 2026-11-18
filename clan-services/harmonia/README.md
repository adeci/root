# Harmonia

Serves the local nix store as a binary cache with
[harmonia](https://github.com/nix-community/harmonia), signed with a generated
key that clients trust through the inventory, so no keys are distributed by
hand.

## Roles

- `server` (NixOS only): serves the cache on `port`, opened on the Tailscale
  interface.
- `client`: uses every server as a substituter and trusts its public key.

## Notes

- Clients reach each server at `<server>.<clan domain>`.
