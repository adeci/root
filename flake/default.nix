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
    ./routeros-netinstall.nix
    ./terranix.nix
    ./tests.nix
    ./users
    ./wrappers.nix
  ];

  # Helpers for flakes that take this one as an input; an option, so several files can add to it.
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
  };
}
