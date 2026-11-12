{ lib, ... }:
let
  dir = ../inventory/resources;

  # Each folder or .nix file becomes resources.<name>.
  resources = lib.mapAttrs' (
    name: _: lib.nameValuePair (lib.removeSuffix ".nix" name) (import (dir + "/${name}"))
  ) (builtins.readDir dir);

  problems = import ./inventory-checks.nix {
    inherit lib resources;
    machines = import ../inventory/machines.nix;
    instances = import ../inventory/instances.nix;
  };
in
{
  options.flake.resources = lib.mkOption { default = { }; };

  # Reading any resource fails while the inventory has problems, listing them all.
  config.flake.resources = lib.mapAttrs (
    _: resource:
    if problems == [ ] then
      resource
    else
      throw "The inventory has problems:\n${lib.concatMapStrings (problem: "  - ${problem}\n") problems}"
  ) resources;
}
