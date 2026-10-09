{ inputs, ... }:
{
  flake.users.alex = inputs.root.lib.mkUser "alex" (import ../../inventory/users/alex.nix);
}
