{ lib, ... }:
let
  dir = ../inventory/resources;
in
{
  options.flake.resources = lib.mkOption { default = { }; };

  # Each folder or .nix file becomes resources.<name>.
  config.flake.resources = lib.mapAttrs' (
    name: _: lib.nameValuePair (lib.removeSuffix ".nix" name) (import (dir + "/${name}"))
  ) (builtins.readDir dir);
}
