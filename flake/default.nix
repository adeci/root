{ lib, ... }:
{
  imports = [
    ./checks.nix
    ./clan.nix
    ./devshell.nix
    ./formatter.nix
    ./inventory
    ./modules.nix
    ./packages.nix
    ./routeros
    ./routeros-netinstall
    ./terranix.nix
    ./tests
    ./users
    ./wrappers.nix
  ];

  # Helpers for downstream flakes; an option so several files can add to it.
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
  };
}
