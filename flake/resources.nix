{ lib, ... }:
let
  dir = ../inventory/resources;
in
{
  options.flake.resources = lib.mkOption { default = { }; };

  config.flake.resources = lib.mapAttrs (name: _: import (dir + "/${name}")) (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir)
  );
}
